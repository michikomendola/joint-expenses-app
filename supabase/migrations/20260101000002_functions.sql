-- =============================================================================
-- Joint Expenses – 0003 server-side operations (RPC)
-- All privileged multi-step operations live here as SECURITY DEFINER
-- functions so the mobile app never needs the service-role key.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Default categories for a brand-new household
-- ---------------------------------------------------------------------------
create or replace function public.seed_default_categories(p_household_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.categories (household_id, name, type, icon, color) values
    -- expenses
    (p_household_id, 'Food & Drinks',  'expense', 'restaurant',          '#F97316'),
    (p_household_id, 'Groceries',      'expense', 'local_grocery_store', '#22C55E'),
    (p_household_id, 'Rent',           'expense', 'home',                '#6366F1'),
    (p_household_id, 'Utilities',      'expense', 'bolt',                '#EAB308'),
    (p_household_id, 'Transportation', 'expense', 'directions_bus',      '#0EA5E9'),
    (p_household_id, 'Shopping',       'expense', 'shopping_bag',        '#EC4899'),
    (p_household_id, 'Entertainment',  'expense', 'movie',               '#A855F7'),
    (p_household_id, 'Healthcare',     'expense', 'medical_services',    '#EF4444'),
    (p_household_id, 'Travel',         'expense', 'flight',              '#14B8A6'),
    (p_household_id, 'Subscriptions',  'expense', 'subscriptions',       '#8B5CF6'),
    (p_household_id, 'Personal',       'expense', 'person',              '#F59E0B'),
    (p_household_id, 'Others',         'expense', 'category',            '#64748B'),
    -- income
    (p_household_id, 'Salary',         'income',  'payments',            '#16A34A'),
    (p_household_id, 'Business',       'income',  'business_center',     '#0D9488'),
    (p_household_id, 'Freelance',      'income',  'laptop',              '#2563EB'),
    (p_household_id, 'Bonus',          'income',  'star',                '#D97706'),
    (p_household_id, 'Investments',    'income',  'trending_up',         '#7C3AED'),
    (p_household_id, 'Gifts',          'income',  'card_giftcard',       '#DB2777'),
    (p_household_id, 'Others',         'income',  'category',            '#64748B')
  on conflict do nothing;
end;
$$;

-- Internal helper: not callable from the client.
revoke all on function public.seed_default_categories(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- create_household(name, currency) → households row
-- Creates the household, adds the caller as owner and seeds categories.
-- ---------------------------------------------------------------------------
create or replace function public.create_household(p_name text, p_currency text default 'PHP')
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_name      text := trim(coalesce(p_name, ''));
  v_currency  text := upper(trim(coalesce(p_currency, 'PHP')));
  v_household public.households;
begin
  if v_uid is null then
    raise exception 'You must be signed in' using errcode = '42501';
  end if;
  if char_length(v_name) < 1 or char_length(v_name) > 60 then
    raise exception 'Household name must be between 1 and 60 characters' using errcode = '22023';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then
    v_currency := 'PHP';
  end if;

  -- Make sure a profile exists even if the auth trigger was added later.
  insert into public.profiles (id, display_name, email)
  select u.id,
         coalesce(nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''), split_part(coalesce(u.email, ''), '@', 1), 'Member'),
         u.email
  from auth.users u
  where u.id = v_uid
  on conflict (id) do nothing;

  insert into public.households (name, owner_id, currency)
  values (v_name, v_uid, v_currency)
  returning * into v_household;

  insert into public.household_members (household_id, user_id, role)
  values (v_household.id, v_uid, 'owner');

  perform public.seed_default_categories(v_household.id);

  return v_household;
end;
$$;

revoke all on function public.create_household(text, text) from public, anon;
grant execute on function public.create_household(text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- create_household_invite(household_id) → { code, expires_at }
-- Returns the plain-text code exactly once; only its SHA-256 hash is stored.
-- Codes use a 32-symbol unambiguous alphabet, 10 symbols = 50 bits of entropy,
-- are single-use and expire after 48 hours.
-- ---------------------------------------------------------------------------
create or replace function public.create_household_invite(p_household_id uuid)
returns table (code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid      uuid := auth.uid();
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes    bytea;
  v_code     text := '';
  v_expires  timestamptz := now() + interval '48 hours';
  i          int;
begin
  if v_uid is null or not public.is_household_member(p_household_id) then
    raise exception 'You are not a member of this household' using errcode = '42501';
  end if;

  v_bytes := extensions.gen_random_bytes(10);
  for i in 0..9 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
  end loop;

  -- Invalidate older unused invites so only one code is live at a time.
  update public.household_invites
     set expires_at = now()
   where household_id = p_household_id
     and used_at is null
     and expires_at > now();

  insert into public.household_invites (household_id, created_by, token_hash, expires_at)
  values (p_household_id, v_uid, encode(extensions.digest(v_code, 'sha256'), 'hex'), v_expires);

  return query select v_code, v_expires;
end;
$$;

revoke all on function public.create_household_invite(uuid) from public, anon;
grant execute on function public.create_household_invite(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- join_household_with_invite(code) → households row
-- Validates the code server-side and adds the caller as a member.
-- ---------------------------------------------------------------------------
create or replace function public.join_household_with_invite(p_code text)
returns public.households
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_code      text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_invite    public.household_invites;
  v_household public.households;
begin
  if v_uid is null then
    raise exception 'You must be signed in' using errcode = '42501';
  end if;
  if char_length(v_code) <> 10 then
    raise exception 'That invite code is not valid' using errcode = '22023';
  end if;

  -- Same profile safety net as create_household.
  insert into public.profiles (id, display_name, email)
  select u.id,
         coalesce(nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''), split_part(coalesce(u.email, ''), '@', 1), 'Member'),
         u.email
  from auth.users u
  where u.id = v_uid
  on conflict (id) do nothing;

  select * into v_invite
  from public.household_invites
  where token_hash = encode(extensions.digest(v_code, 'sha256'), 'hex')
  for update;

  if not found then
    raise exception 'That invite code is not valid' using errcode = '22023';
  end if;
  if v_invite.used_at is not null then
    raise exception 'This invite code has already been used' using errcode = '22023';
  end if;
  if v_invite.expires_at < now() then
    raise exception 'This invite code has expired. Ask for a new one.' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.household_members
    where household_id = v_invite.household_id and user_id = v_uid
  ) then
    raise exception 'You are already a member of this household' using errcode = '22023';
  end if;

  insert into public.household_members (household_id, user_id, role)
  values (v_invite.household_id, v_uid, 'member');

  update public.household_invites
     set used_at = now(), used_by = v_uid
   where id = v_invite.id;

  select * into v_household from public.households where id = v_invite.household_id;
  return v_household;
end;
$$;

revoke all on function public.join_household_with_invite(text) from public, anon;
grant execute on function public.join_household_with_invite(text) to authenticated;

-- ---------------------------------------------------------------------------
-- reassign_and_delete_category(category_id, replacement_id)
-- Deletes a category. If it is in use, all transactions are moved to the
-- replacement first (same household, same type). Runs as definer because
-- members may only edit their own transactions directly.
-- ---------------------------------------------------------------------------
create or replace function public.reassign_and_delete_category(
  p_category_id uuid,
  p_replacement_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category    public.categories;
  v_replacement public.categories;
  v_in_use      bigint;
begin
  select * into v_category from public.categories where id = p_category_id;
  if not found then
    raise exception 'Category not found' using errcode = '22023';
  end if;
  if not public.is_household_member(v_category.household_id) then
    raise exception 'You are not a member of this household' using errcode = '42501';
  end if;

  select count(*) into v_in_use from public.transactions where category_id = p_category_id;

  if v_in_use > 0 then
    if p_replacement_id is null then
      raise exception 'This category is in use. Choose a replacement category first.' using errcode = '22023';
    end if;
    select * into v_replacement from public.categories where id = p_replacement_id;
    if not found
       or v_replacement.household_id <> v_category.household_id
       or v_replacement.type <> v_category.type
       or v_replacement.id = v_category.id then
      raise exception 'The replacement must be a different % category in this household', v_category.type
        using errcode = '22023';
    end if;

    update public.transactions
       set category_id = p_replacement_id
     where category_id = p_category_id;
  end if;

  delete from public.categories where id = p_category_id;
end;
$$;

revoke all on function public.reassign_and_delete_category(uuid, uuid) from public, anon;
grant execute on function public.reassign_and_delete_category(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Lock down trigger helpers so they cannot be invoked directly.
-- ---------------------------------------------------------------------------
revoke all on function public.handle_new_user()                 from public, anon, authenticated;
revoke all on function public.handle_user_email_updated()       from public, anon, authenticated;
revoke all on function public.validate_transaction_category()   from public, anon, authenticated;
