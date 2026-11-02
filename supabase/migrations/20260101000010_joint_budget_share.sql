-- =============================================================================
-- Joint leftover share. Surplus carries over. A negative leftover can be
-- marked shared so the pot returns to 0. This is a record only — the actual
-- GCash/cash transfer stays outside the app.
-- =============================================================================

create table if not exists public.joint_budget_settlements (
  id                 uuid primary key default gen_random_uuid(),
  household_id       uuid not null references public.households (id) on delete cascade,
  adjustment_amount  numeric(14, 2) not null check (adjustment_amount > 0),
  leftover_before    numeric(14, 2) not null check (leftover_before < 0),
  shared_at          timestamptz not null default now(),
  marked_by          uuid not null references public.profiles (id) on delete restrict,
  created_at         timestamptz not null default now()
);

create index if not exists joint_budget_settlements_household_idx
  on public.joint_budget_settlements (household_id, shared_at desc);

alter table public.joint_budget_settlements enable row level security;

drop policy if exists "joint_budget_settlements_select_member" on public.joint_budget_settlements;
create policy "joint_budget_settlements_select_member"
  on public.joint_budget_settlements for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "joint_budget_settlements_insert_member" on public.joint_budget_settlements;
create policy "joint_budget_settlements_insert_member"
  on public.joint_budget_settlements for insert to authenticated
  with check (
    public.is_household_member(household_id)
    and marked_by = auth.uid()
  );

drop policy if exists "joint_budget_settlements_delete_member" on public.joint_budget_settlements;
create policy "joint_budget_settlements_delete_member"
  on public.joint_budget_settlements for delete to authenticated
  using (public.is_household_member(household_id));

alter table public.joint_budget_settlements replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'joint_budget_settlements'
  ) then
    alter publication supabase_realtime add table public.joint_budget_settlements;
  end if;
end;
$$;

create or replace function public._joint_leftover(p_household_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select sum(case
      when type = 'income' then amount
      else -amount
    end)
    from public.transactions
    where household_id = p_household_id
      and expense_scope = 'joint'
  ), 0)
  + coalesce((
    select sum(adjustment_amount)
    from public.joint_budget_settlements
    where household_id = p_household_id
  ), 0);
$$;

create or replace function public.share_joint_deficit(p_household_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  leftover numeric;
  rec public.joint_budget_settlements;
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
  if not public.is_household_member(p_household_id) then
    raise exception 'You are not a member of this household' using errcode = '42501';
  end if;

  leftover := public._joint_leftover(p_household_id);
  if leftover >= 0 then
    raise exception 'Joint leftover is not negative.' using errcode = 'P0001';
  end if;

  insert into public.joint_budget_settlements (
    household_id, adjustment_amount, leftover_before, marked_by
  ) values (
    p_household_id, abs(leftover), leftover, auth.uid()
  )
  returning * into rec;

  return jsonb_build_object(
    'id', rec.id,
    'household_id', rec.household_id,
    'adjustment_amount', rec.adjustment_amount,
    'leftover_before', rec.leftover_before,
    'shared_at', rec.shared_at,
    'marked_by', rec.marked_by
  );
end;
$$;

create or replace function public.undo_joint_deficit_share(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  select household_id into hid
  from public.joint_budget_settlements
  where id = p_id;

  if hid is null then
    raise exception 'That share record was not found.' using errcode = 'P0001';
  end if;
  if not public.is_household_member(hid) then
    raise exception 'You are not a member of this household' using errcode = '42501';
  end if;

  delete from public.joint_budget_settlements where id = p_id;
end;
$$;

revoke all on function public._joint_leftover(uuid) from public, anon;
revoke all on function public.share_joint_deficit(uuid) from public, anon;
revoke all on function public.undo_joint_deficit_share(uuid) from public, anon;
grant execute on function public._joint_leftover(uuid) to authenticated;
grant execute on function public.share_joint_deficit(uuid) to authenticated;
grant execute on function public.undo_joint_deficit_share(uuid) to authenticated;
