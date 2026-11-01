-- =============================================================================
-- Joint Expenses – 0002 Row Level Security
-- Household-level isolation. Every table is locked down; access is granted
-- only to authenticated members of the relevant household.
-- =============================================================================

alter table public.profiles          enable row level security;
alter table public.households        enable row level security;
alter table public.household_members enable row level security;
alter table public.categories        enable row level security;
alter table public.transactions      enable row level security;
alter table public.household_invites enable row level security;

-- ---------------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER so policies never recurse into RLS)
-- ---------------------------------------------------------------------------
create or replace function public.is_household_member(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.household_members
    where household_id = p_household_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.is_household_owner(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.households
    where id = p_household_id
      and owner_id = auth.uid()
  );
$$;

create or replace function public.shares_household_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.household_members mine
    join public.household_members theirs on theirs.household_id = mine.household_id
    where mine.user_id = auth.uid()
      and theirs.user_id = p_user_id
  );
$$;

revoke all on function public.is_household_member(uuid)   from public, anon;
revoke all on function public.is_household_owner(uuid)    from public, anon;
revoke all on function public.shares_household_with(uuid) from public, anon;
grant execute on function public.is_household_member(uuid)   to authenticated;
grant execute on function public.is_household_owner(uuid)    to authenticated;
grant execute on function public.shares_household_with(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
drop policy if exists "profiles_select_self_or_housemates" on public.profiles;
create policy "profiles_select_self_or_housemates"
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_household_with(id));

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
  on public.profiles for insert to authenticated
  with check (id = auth.uid());

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- households (created only through the create_household() RPC)
-- ---------------------------------------------------------------------------
drop policy if exists "households_select_members" on public.households;
create policy "households_select_members"
  on public.households for select to authenticated
  using (public.is_household_member(id));

drop policy if exists "households_update_members" on public.households;
create policy "households_update_members"
  on public.households for update to authenticated
  using (public.is_household_member(id))
  with check (public.is_household_member(id));

drop policy if exists "households_delete_owner" on public.households;
create policy "households_delete_owner"
  on public.households for delete to authenticated
  using (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- household_members (rows are inserted only through RPCs)
-- ---------------------------------------------------------------------------
drop policy if exists "members_select_housemates" on public.household_members;
create policy "members_select_housemates"
  on public.household_members for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "members_delete_self_or_owner" on public.household_members;
create policy "members_delete_self_or_owner"
  on public.household_members for delete to authenticated
  using (
    (user_id = auth.uid() and role <> 'owner')
    or (public.is_household_owner(household_id) and user_id <> auth.uid())
  );

-- ---------------------------------------------------------------------------
-- categories – shared, managed by any household member
-- ---------------------------------------------------------------------------
drop policy if exists "categories_select_members" on public.categories;
create policy "categories_select_members"
  on public.categories for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "categories_insert_members" on public.categories;
create policy "categories_insert_members"
  on public.categories for insert to authenticated
  with check (public.is_household_member(household_id));

drop policy if exists "categories_update_members" on public.categories;
create policy "categories_update_members"
  on public.categories for update to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

drop policy if exists "categories_delete_members" on public.categories;
create policy "categories_delete_members"
  on public.categories for delete to authenticated
  using (public.is_household_member(household_id));

-- ---------------------------------------------------------------------------
-- transactions – visible to all members, writable only by the creator
-- ---------------------------------------------------------------------------
drop policy if exists "transactions_select_members" on public.transactions;
create policy "transactions_select_members"
  on public.transactions for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "transactions_insert_self" on public.transactions;
create policy "transactions_insert_self"
  on public.transactions for insert to authenticated
  with check (user_id = auth.uid() and public.is_household_member(household_id));

drop policy if exists "transactions_update_own" on public.transactions;
create policy "transactions_update_own"
  on public.transactions for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_household_member(household_id));

drop policy if exists "transactions_delete_own" on public.transactions;
create policy "transactions_delete_own"
  on public.transactions for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- household_invites – members can see invite metadata (hashes only);
-- creation and redemption happen through RPCs.
-- ---------------------------------------------------------------------------
drop policy if exists "invites_select_members" on public.household_invites;
create policy "invites_select_members"
  on public.household_invites for select to authenticated
  using (public.is_household_member(household_id));

drop policy if exists "invites_delete_members" on public.household_invites;
create policy "invites_delete_members"
  on public.household_invites for delete to authenticated
  using (public.is_household_member(household_id));
