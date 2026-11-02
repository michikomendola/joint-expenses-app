-- =============================================================================
-- Joint Expenses – 0005 credit-card statement import
-- Extends transactions with personal/joint ownership and adds import,
-- cardholder, installment and review tables. Existing rows stay valid:
-- they become personal expenses assigned to the member who created them.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.expense_scope as enum ('personal', 'joint');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.transaction_source as enum ('manual', 'credit_card_statement');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.statement_import_status as enum (
    'processing', 'ready_for_review', 'imported', 'cancelled', 'failed'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.statement_line_type as enum (
    'purchase', 'installment_charge', 'payment', 'refund',
    'finance_charge', 'bank_fee', 'summary'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.statement_review_status as enum (
    'needs_review', 'classified', 'excluded', 'already_imported',
    'possible_duplicate', 'needs_attention'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.card_type as enum ('principal', 'supplementary', 'unknown');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.installment_plan_status as enum ('active', 'completed', 'unknown');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Extend transactions
-- ---------------------------------------------------------------------------
alter table public.transactions
  add column if not exists expense_scope public.expense_scope not null default 'personal',
  add column if not exists assigned_user_id uuid references public.profiles (id) on delete set null,
  add column if not exists source_type public.transaction_source not null default 'manual',
  add column if not exists statement_import_id uuid,
  add column if not exists cardholder_id uuid,
  add column if not exists installment_plan_id uuid,
  add column if not exists post_date date,
  add column if not exists external_transaction_key text,
  add column if not exists original_currency text,
  add column if not exists original_amount numeric(14, 2);

-- Back-fill: historical rows belong personally to the member who recorded them.
update public.transactions
   set assigned_user_id = user_id
 where expense_scope = 'personal'
   and assigned_user_id is null;

alter table public.transactions
  drop constraint if exists transactions_scope_owner_chk;
alter table public.transactions
  add constraint transactions_scope_owner_chk check (
    (expense_scope = 'personal' and assigned_user_id is not null)
    or (expense_scope = 'joint' and assigned_user_id is null)
  );

alter table public.transactions
  drop constraint if exists transactions_original_amount_chk;
alter table public.transactions
  add constraint transactions_original_amount_chk check (
    original_amount is null or original_amount > 0
  );

create unique index if not exists transactions_household_external_key_uidx
  on public.transactions (household_id, external_transaction_key)
  where external_transaction_key is not null;

create index if not exists transactions_scope_assigned_idx
  on public.transactions (household_id, expense_scope, assigned_user_id);
create index if not exists transactions_statement_idx
  on public.transactions (statement_import_id);

-- ---------------------------------------------------------------------------
-- statement_imports
-- ---------------------------------------------------------------------------
create table if not exists public.statement_imports (
  id                    uuid primary key default gen_random_uuid(),
  household_id          uuid not null references public.households (id) on delete cascade,
  uploaded_by           uuid not null references public.profiles (id) on delete restrict,
  bank_name             text not null check (char_length(trim(bank_name)) between 1 and 40),
  statement_date        date,
  payment_due_date      date,
  billing_period_start  date,
  billing_period_end    date,
  statement_fingerprint text not null,
  statement_reference   text,
  file_name             text,
  currency              text not null default 'PHP' check (currency ~ '^[A-Z]{3}$'),
  status                public.statement_import_status not null default 'processing',
  imported_at           timestamptz,
  created_at            timestamptz not null default now()
);

create index if not exists statement_imports_household_idx
  on public.statement_imports (household_id, created_at desc);
create unique index if not exists statement_imports_fingerprint_imported_uidx
  on public.statement_imports (household_id, statement_fingerprint)
  where status = 'imported';

-- ---------------------------------------------------------------------------
-- statement_cardholders
-- ---------------------------------------------------------------------------
create table if not exists public.statement_cardholders (
  id                            uuid primary key default gen_random_uuid(),
  household_id                  uuid not null references public.households (id) on delete cascade,
  external_card_identifier_hash text not null,
  masked_identifier             text not null,
  display_name                  text not null,
  card_type                     public.card_type not null default 'unknown',
  mapped_user_id                uuid references public.profiles (id) on delete set null,
  created_at                    timestamptz not null default now(),
  unique (household_id, external_card_identifier_hash)
);

create index if not exists statement_cardholders_household_idx
  on public.statement_cardholders (household_id);

-- ---------------------------------------------------------------------------
-- installment_plans
-- ---------------------------------------------------------------------------
create table if not exists public.installment_plans (
  id                       uuid primary key default gen_random_uuid(),
  household_id             uuid not null references public.households (id) on delete cascade,
  cardholder_id            uuid references public.statement_cardholders (id) on delete set null,
  merchant_name            text not null,
  normalized_merchant_name text not null,
  original_purchase_date   date,
  original_purchase_amount numeric(14, 2) check (original_purchase_amount is null or original_purchase_amount > 0),
  monthly_amount           numeric(14, 2) not null check (monthly_amount > 0),
  total_installments       integer not null check (total_installments > 0),
  remaining_balance        numeric(14, 2) check (remaining_balance is null or remaining_balance >= 0),
  last_payment_date        date,
  expense_scope            public.expense_scope not null,
  assigned_user_id         uuid references public.profiles (id) on delete set null,
  category_id              uuid references public.categories (id) on delete set null,
  status                   public.installment_plan_status not null default 'active',
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  constraint installment_plans_scope_owner_chk check (
    (expense_scope = 'personal' and assigned_user_id is not null)
    or (expense_scope = 'joint' and assigned_user_id is null)
  )
);

create index if not exists installment_plans_match_idx
  on public.installment_plans (
    household_id, normalized_merchant_name, monthly_amount, total_installments
  );

drop trigger if exists installment_plans_set_updated_at on public.installment_plans;
create trigger installment_plans_set_updated_at
  before update on public.installment_plans
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- installment_charges
-- ---------------------------------------------------------------------------
create table if not exists public.installment_charges (
  id                      uuid primary key default gen_random_uuid(),
  installment_plan_id     uuid not null references public.installment_plans (id) on delete cascade,
  statement_import_id     uuid not null references public.statement_imports (id) on delete cascade,
  transaction_id          uuid references public.transactions (id) on delete set null,
  installment_number      integer not null check (installment_number > 0),
  billed_transaction_date date not null,
  monthly_amount          numeric(14, 2) not null check (monthly_amount > 0),
  created_at              timestamptz not null default now(),
  unique (installment_plan_id, statement_import_id, installment_number)
);

create index if not exists installment_charges_import_idx
  on public.installment_charges (statement_import_id);

-- ---------------------------------------------------------------------------
-- statement_import_lines (audit / review snapshot)
-- ---------------------------------------------------------------------------
create table if not exists public.statement_import_lines (
  id                             uuid primary key default gen_random_uuid(),
  statement_import_id            uuid not null references public.statement_imports (id) on delete cascade,
  source_page                    integer,
  source_row_identifier          text,
  cardholder_id                  uuid references public.statement_cardholders (id) on delete set null,
  transaction_date               date,
  post_date                      date,
  description                    text,
  amount                         numeric(14, 2),
  currency                       text not null default 'PHP',
  detected_type                  public.statement_line_type not null,
  installment_number             integer,
  total_installments             integer,
  suggested_category_id          uuid references public.categories (id) on delete set null,
  expense_scope                  public.expense_scope,
  assigned_user_id               uuid references public.profiles (id) on delete set null,
  confidence_score               numeric(4, 3) check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  review_status                  public.statement_review_status not null default 'needs_review',
  matched_existing_transaction_id uuid references public.transactions (id) on delete set null,
  matched_installment_plan_id    uuid references public.installment_plans (id) on delete set null,
  external_transaction_key       text,
  original_currency              text,
  original_amount                numeric(14, 2),
  created_at                     timestamptz not null default now()
);

create index if not exists statement_import_lines_import_idx
  on public.statement_import_lines (statement_import_id);

-- ---------------------------------------------------------------------------
-- Optional merchant → category memory
-- ---------------------------------------------------------------------------
create table if not exists public.merchant_category_prefs (
  id                   uuid primary key default gen_random_uuid(),
  household_id         uuid not null references public.households (id) on delete cascade,
  normalized_merchant  text not null,
  category_id          uuid not null references public.categories (id) on delete cascade,
  updated_at           timestamptz not null default now(),
  unique (household_id, normalized_merchant)
);

-- FKs that could not be declared earlier (circular).
do $$ begin
  alter table public.transactions
    add constraint transactions_statement_import_fk
    foreign key (statement_import_id) references public.statement_imports (id) on delete set null;
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.transactions
    add constraint transactions_cardholder_fk
    foreign key (cardholder_id) references public.statement_cardholders (id) on delete set null;
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.transactions
    add constraint transactions_installment_plan_fk
    foreign key (installment_plan_id) references public.installment_plans (id) on delete set null;
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.statement_imports       enable row level security;
alter table public.statement_cardholders   enable row level security;
alter table public.installment_plans       enable row level security;
alter table public.installment_charges     enable row level security;
alter table public.statement_import_lines  enable row level security;
alter table public.merchant_category_prefs enable row level security;

drop policy if exists "statement_imports_members" on public.statement_imports;
create policy "statement_imports_members"
  on public.statement_imports for all to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id) and uploaded_by = auth.uid());

drop policy if exists "statement_cardholders_members" on public.statement_cardholders;
create policy "statement_cardholders_members"
  on public.statement_cardholders for all to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

drop policy if exists "installment_plans_members" on public.installment_plans;
create policy "installment_plans_members"
  on public.installment_plans for all to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

drop policy if exists "installment_charges_members" on public.installment_charges;
create policy "installment_charges_members"
  on public.installment_charges for all to authenticated
  using (
    exists (
      select 1 from public.installment_plans p
      where p.id = installment_plan_id
        and public.is_household_member(p.household_id)
    )
  )
  with check (
    exists (
      select 1 from public.installment_plans p
      where p.id = installment_plan_id
        and public.is_household_member(p.household_id)
    )
  );

drop policy if exists "statement_import_lines_members" on public.statement_import_lines;
create policy "statement_import_lines_members"
  on public.statement_import_lines for all to authenticated
  using (
    exists (
      select 1 from public.statement_imports i
      where i.id = statement_import_id
        and public.is_household_member(i.household_id)
    )
  )
  with check (
    exists (
      select 1 from public.statement_imports i
      where i.id = statement_import_id
        and public.is_household_member(i.household_id)
    )
  );

drop policy if exists "merchant_prefs_members" on public.merchant_category_prefs;
create policy "merchant_prefs_members"
  on public.merchant_category_prefs for all to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

-- Members may update classification of imported household expenses.
drop policy if exists "transactions_update_own" on public.transactions;
create policy "transactions_update_own"
  on public.transactions for update to authenticated
  using (
    user_id = auth.uid()
    or public.is_household_member(household_id)
  )
  with check (
    public.is_household_member(household_id)
    and user_id = user_id
  );

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
alter table public.statement_imports     replica identity full;
alter table public.installment_plans     replica identity full;
alter table public.statement_cardholders replica identity full;

do $$
declare
  t text;
begin
  foreach t in array array['statement_imports', 'installment_plans', 'statement_cardholders'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end;
$$;
