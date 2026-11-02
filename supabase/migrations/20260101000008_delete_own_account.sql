-- =============================================================================
-- Joint Expenses – delete the signed-in account
-- Play requires an in-app way to delete an account and the personal data
-- attached to it. Shared household records stay with the remaining member.
-- Run in the Supabase SQL editor after the earlier migrations.
-- =============================================================================

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_household uuid;
  v_other uuid;
begin
  if v_uid is null then
    raise exception 'You need to be signed in to delete your account.'
      using errcode = '42501';
  end if;

  for v_household in
    select household_id
    from (
      select household_id from public.household_members where user_id = v_uid
      union
      select id as household_id from public.households where owner_id = v_uid
    ) households_for_user
  loop
    select m.user_id
      into v_other
    from public.household_members m
    where m.household_id = v_household
      and m.user_id <> v_uid
    order by case when m.role = 'owner' then 0 else 1 end, m.joined_at
    limit 1;

    if v_other is null then
      -- Sole member: the household exists only for this account.
      delete from public.households where id = v_household;
      continue;
    end if;

    update public.households
       set owner_id = v_other
     where id = v_household
       and owner_id = v_uid;

    update public.household_members
       set role = 'owner'
     where household_id = v_household
       and user_id = v_other;

    -- Personal expenses and installment plans belong to the departing member.
    delete from public.transactions
     where household_id = v_household
       and expense_scope = 'personal'
       and assigned_user_id = v_uid;

    delete from public.installment_plans
     where household_id = v_household
       and expense_scope = 'personal'
       and assigned_user_id = v_uid;

    -- Joint records stay. Point them at the remaining member so deleting the
    -- profile does not cascade them away.
    update public.transactions
       set user_id = v_other
     where household_id = v_household
       and user_id = v_uid;

    update public.statement_imports
       set uploaded_by = v_other
     where household_id = v_household
       and uploaded_by = v_uid;

    delete from public.household_members
     where household_id = v_household
       and user_id = v_uid;
  end loop;

  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
