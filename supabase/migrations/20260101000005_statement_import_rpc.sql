-- =============================================================================
-- Joint Expenses – 0006 statement import RPCs
-- Atomic, idempotent import. The mobile app never needs the service-role key.
-- =============================================================================

create or replace function public._is_household_member_of_profile(p_household_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.household_members
    where household_id = p_household_id and user_id = p_user_id
  );
$$;

revoke all on function public._is_household_member_of_profile(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- import_statement_expenses(jsonb) → summary jsonb
-- ---------------------------------------------------------------------------
create or replace function public.import_statement_expenses(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid           uuid := auth.uid();
  v_household_id  uuid;
  v_import        public.statement_imports;
  v_imported      int := 0;
  v_already       int := 0;
  v_skipped       int := 0;
  v_failed        int := 0;
  v_line          jsonb;
  v_cardholder    public.statement_cardholders;
  v_plan          public.installment_plans;
  v_tx            public.transactions;
  v_scope         public.expense_scope;
  v_assigned      uuid;
  v_type          public.statement_line_type;
  v_status        public.statement_review_status;
  v_key           text;
  v_amount        numeric(14, 2);
  v_category_id   uuid;
  v_plan_id       uuid;
begin
  if v_uid is null then
    raise exception 'You must be signed in' using errcode = '42501';
  end if;

  v_household_id := (p_payload ->> 'household_id')::uuid;
  if v_household_id is null or not public.is_household_member(v_household_id) then
    raise exception 'Not a member of this household' using errcode = '42501';
  end if;

  -- Re-import of an already-imported fingerprint is a no-op for expenses.
  select * into v_import
    from public.statement_imports
   where household_id = v_household_id
     and statement_fingerprint = p_payload ->> 'statement_fingerprint'
     and status = 'imported'
   limit 1;

  if found then
    return jsonb_build_object(
      'import_id', v_import.id,
      'imported', 0,
      'already_imported', (
        select count(*) from public.statement_import_lines
        where statement_import_id = v_import.id
          and review_status = 'already_imported'
      ),
      'skipped', 0,
      'failed', 0,
      'duplicate_statement', true
    );
  end if;

  insert into public.statement_imports (
    household_id, uploaded_by, bank_name, statement_date, payment_due_date,
    billing_period_start, billing_period_end, statement_fingerprint,
    statement_reference, file_name, currency, status
  ) values (
    v_household_id,
    v_uid,
    coalesce(nullif(trim(p_payload ->> 'bank_name'), ''), 'BPI'),
    nullif(p_payload ->> 'statement_date', '')::date,
    nullif(p_payload ->> 'payment_due_date', '')::date,
    nullif(p_payload ->> 'billing_period_start', '')::date,
    nullif(p_payload ->> 'billing_period_end', '')::date,
    p_payload ->> 'statement_fingerprint',
    nullif(p_payload ->> 'statement_reference', ''),
    nullif(p_payload ->> 'file_name', ''),
    coalesce(nullif(p_payload ->> 'currency', ''), 'PHP'),
    'processing'
  )
  returning * into v_import;

  -- Cardholders
  if jsonb_typeof(p_payload -> 'cardholders') = 'array' then
    for v_line in select value from jsonb_array_elements(p_payload -> 'cardholders')
    loop
      insert into public.statement_cardholders (
        household_id, external_card_identifier_hash, masked_identifier,
        display_name, card_type, mapped_user_id
      ) values (
        v_household_id,
        v_line ->> 'external_card_identifier_hash',
        coalesce(v_line ->> 'masked_identifier', '****'),
        coalesce(nullif(trim(v_line ->> 'display_name'), ''), 'Cardholder'),
        coalesce((v_line ->> 'card_type')::public.card_type, 'unknown'),
        nullif(v_line ->> 'mapped_user_id', '')::uuid
      )
      on conflict (household_id, external_card_identifier_hash) do update
        set display_name = excluded.display_name,
            card_type = excluded.card_type,
            mapped_user_id = coalesce(excluded.mapped_user_id, public.statement_cardholders.mapped_user_id)
      returning * into v_cardholder;
    end loop;
  end if;

  for v_line in select value from jsonb_array_elements(coalesce(p_payload -> 'lines', '[]'::jsonb))
  loop
    begin
      v_status := coalesce((v_line ->> 'review_status')::public.statement_review_status, 'needs_review');
      v_type := coalesce((v_line ->> 'detected_type')::public.statement_line_type, 'purchase');
      v_key := nullif(v_line ->> 'external_transaction_key', '');
      v_amount := nullif(v_line ->> 'amount', '')::numeric;
      v_category_id := nullif(v_line ->> 'category_id', '')::uuid;
      v_scope := nullif(v_line ->> 'expense_scope', '')::public.expense_scope;
      v_assigned := nullif(v_line ->> 'assigned_user_id', '')::uuid;
      v_plan_id := null;

      if v_status in ('excluded', 'needs_review', 'needs_attention') then
        v_skipped := v_skipped + 1;
      elsif v_type not in ('purchase', 'installment_charge', 'bank_fee') then
        v_skipped := v_skipped + 1;
        v_status := 'excluded';
      elsif v_status = 'already_imported' or (
        v_key is not null and exists (
          select 1 from public.transactions
          where household_id = v_household_id and external_transaction_key = v_key
        )
      ) then
        v_already := v_already + 1;
        v_status := 'already_imported';
      elsif v_scope is null or v_amount is null or v_amount <= 0 or v_category_id is null
            or (v_line ->> 'transaction_date') is null
            or (v_scope = 'personal' and v_assigned is null)
            or (v_scope = 'joint' and v_assigned is not null)
            or (v_assigned is not null and not public._is_household_member_of_profile(v_household_id, v_assigned))
      then
        v_failed := v_failed + 1;
        v_status := 'needs_attention';
      else
        -- Cardholder
        v_cardholder := null;
        if nullif(v_line ->> 'card_identifier_hash', '') is not null then
          select * into v_cardholder
            from public.statement_cardholders
           where household_id = v_household_id
             and external_card_identifier_hash = v_line ->> 'card_identifier_hash';
        end if;

        -- Installment plan memory
        if v_type = 'installment_charge' then
          if nullif(v_line ->> 'matched_installment_plan_id', '') is not null then
            select * into v_plan from public.installment_plans
             where id = (v_line ->> 'matched_installment_plan_id')::uuid
               and household_id = v_household_id;
          else
            v_plan := null;
            select * into v_plan
              from public.installment_plans
             where household_id = v_household_id
               and normalized_merchant_name = lower(trim(v_line ->> 'normalized_merchant'))
               and monthly_amount = v_amount
               and total_installments = coalesce((v_line ->> 'total_installments')::int, total_installments)
               and (
                 v_cardholder is null
                 or cardholder_id is null
                 or cardholder_id = v_cardholder.id
               )
             order by created_at
             limit 1;
          end if;

          if v_plan is null then
            insert into public.installment_plans (
              household_id, cardholder_id, merchant_name, normalized_merchant_name,
              original_purchase_date, original_purchase_amount, monthly_amount,
              total_installments, remaining_balance, last_payment_date,
              expense_scope, assigned_user_id, category_id, status
            ) values (
              v_household_id,
              v_cardholder.id,
              coalesce(nullif(trim(v_line ->> 'description'), ''), 'Installment'),
              coalesce(nullif(lower(trim(v_line ->> 'normalized_merchant')), ''), 'installment'),
              nullif(v_line ->> 'original_purchase_date', '')::date,
              nullif(v_line ->> 'original_purchase_amount', '')::numeric,
              v_amount,
              coalesce((v_line ->> 'total_installments')::int, 1),
              nullif(v_line ->> 'remaining_balance', '')::numeric,
              nullif(v_line ->> 'last_payment_date', '')::date,
              v_scope,
              v_assigned,
              v_category_id,
              case
                when (v_line ->> 'installment_number')::int is not null
                 and (v_line ->> 'total_installments')::int is not null
                 and (v_line ->> 'installment_number')::int >= (v_line ->> 'total_installments')::int
                then 'completed'::public.installment_plan_status
                else 'active'::public.installment_plan_status
              end
            )
            returning * into v_plan;
          else
            update public.installment_plans
               set expense_scope = v_scope,
                   assigned_user_id = v_assigned,
                   category_id = coalesce(v_category_id, category_id),
                   remaining_balance = coalesce(nullif(v_line ->> 'remaining_balance', '')::numeric, remaining_balance),
                   last_payment_date = coalesce(nullif(v_line ->> 'last_payment_date', '')::date, last_payment_date),
                   original_purchase_date = coalesce(original_purchase_date, nullif(v_line ->> 'original_purchase_date', '')::date),
                   original_purchase_amount = coalesce(original_purchase_amount, nullif(v_line ->> 'original_purchase_amount', '')::numeric),
                   status = case
                     when (v_line ->> 'installment_number')::int is not null
                      and total_installments is not null
                      and (v_line ->> 'installment_number')::int >= total_installments
                     then 'completed'::public.installment_plan_status
                     else status
                   end
             where id = v_plan.id
             returning * into v_plan;
          end if;
          v_plan_id := v_plan.id;
        end if;

        insert into public.transactions (
          household_id, user_id, type, amount, category_id, description,
          transaction_date, expense_scope, assigned_user_id, source_type,
          statement_import_id, cardholder_id, installment_plan_id, post_date,
          external_transaction_key, original_currency, original_amount
        ) values (
          v_household_id,
          v_uid,
          'expense',
          v_amount,
          v_category_id,
          nullif(trim(v_line ->> 'description'), ''),
          (v_line ->> 'transaction_date')::date,
          v_scope,
          v_assigned,
          'credit_card_statement',
          v_import.id,
          v_cardholder.id,
          v_plan_id,
          nullif(v_line ->> 'post_date', '')::date,
          v_key,
          nullif(v_line ->> 'original_currency', ''),
          nullif(v_line ->> 'original_amount', '')::numeric
        )
        on conflict (household_id, external_transaction_key)
          where external_transaction_key is not null
        do nothing
        returning * into v_tx;

        if v_tx is null then
          v_already := v_already + 1;
          v_status := 'already_imported';
        else
          v_imported := v_imported + 1;
          v_status := 'classified';

          if v_plan_id is not null then
            insert into public.installment_charges (
              installment_plan_id, statement_import_id, transaction_id,
              installment_number, billed_transaction_date, monthly_amount
            ) values (
              v_plan_id,
              v_import.id,
              v_tx.id,
              coalesce((v_line ->> 'installment_number')::int, 1),
              (v_line ->> 'transaction_date')::date,
              v_amount
            )
            on conflict (installment_plan_id, statement_import_id, installment_number) do nothing;
          end if;

          if nullif(v_line ->> 'normalized_merchant', '') is not null then
            insert into public.merchant_category_prefs (household_id, normalized_merchant, category_id)
            values (v_household_id, lower(trim(v_line ->> 'normalized_merchant')), v_category_id)
            on conflict (household_id, normalized_merchant) do update
              set category_id = excluded.category_id, updated_at = now();
          end if;
        end if;
      end if;

      insert into public.statement_import_lines (
        statement_import_id, source_page, source_row_identifier, cardholder_id,
        transaction_date, post_date, description, amount, currency, detected_type,
        installment_number, total_installments, suggested_category_id,
        expense_scope, assigned_user_id, confidence_score, review_status,
        matched_existing_transaction_id, matched_installment_plan_id,
        external_transaction_key, original_currency, original_amount
      ) values (
        v_import.id,
        nullif(v_line ->> 'source_page', '')::int,
        nullif(v_line ->> 'source_row_identifier', ''),
        v_cardholder.id,
        nullif(v_line ->> 'transaction_date', '')::date,
        nullif(v_line ->> 'post_date', '')::date,
        nullif(v_line ->> 'description', ''),
        v_amount,
        coalesce(v_line ->> 'currency', 'PHP'),
        v_type,
        nullif(v_line ->> 'installment_number', '')::int,
        nullif(v_line ->> 'total_installments', '')::int,
        v_category_id,
        v_scope,
        v_assigned,
        nullif(v_line ->> 'confidence_score', '')::numeric,
        v_status,
        v_tx.id,
        v_plan_id,
        v_key,
        nullif(v_line ->> 'original_currency', ''),
        nullif(v_line ->> 'original_amount', '')::numeric
      );
    exception when others then
      v_failed := v_failed + 1;
    end;
  end loop;

  update public.statement_imports
     set status = 'imported', imported_at = now()
   where id = v_import.id;

  return jsonb_build_object(
    'import_id', v_import.id,
    'imported', v_imported,
    'already_imported', v_already,
    'skipped', v_skipped,
    'failed', v_failed,
    'duplicate_statement', false
  );
end;
$$;

revoke all on function public.import_statement_expenses(jsonb) from public, anon;
grant execute on function public.import_statement_expenses(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- update_expense_classification – any household member, imported or not
-- ---------------------------------------------------------------------------
create or replace function public.update_expense_classification(
  p_transaction_id uuid,
  p_expense_scope public.expense_scope,
  p_assigned_user_id uuid
)
returns public.transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tx public.transactions;
begin
  select * into v_tx from public.transactions where id = p_transaction_id;
  if not found then
    raise exception 'Transaction not found' using errcode = 'P0002';
  end if;
  if not public.is_household_member(v_tx.household_id) then
    raise exception 'Not a member of this household' using errcode = '42501';
  end if;
  if v_tx.type <> 'expense' then
    raise exception 'Only expenses can be classified' using errcode = '22023';
  end if;
  if p_expense_scope = 'personal' then
    if p_assigned_user_id is null
       or not public._is_household_member_of_profile(v_tx.household_id, p_assigned_user_id) then
      raise exception 'Personal expenses need a household member' using errcode = '22023';
    end if;
  else
    p_assigned_user_id := null;
  end if;

  update public.transactions
     set expense_scope = p_expense_scope,
         assigned_user_id = p_assigned_user_id
   where id = p_transaction_id
   returning * into v_tx;

  if v_tx.installment_plan_id is not null then
    update public.installment_plans
       set expense_scope = p_expense_scope,
           assigned_user_id = p_assigned_user_id
     where id = v_tx.installment_plan_id;
  end if;

  return v_tx;
end;
$$;

revoke all on function public.update_expense_classification(uuid, public.expense_scope, uuid) from public, anon;
grant execute on function public.update_expense_classification(uuid, public.expense_scope, uuid) to authenticated;
