-- =============================================================================
-- Joint Expenses – fix household invite generation
-- Paste this into the Supabase SQL editor (or `supabase db push`) if invite
-- codes fail with a generic "server rejected the request".
--
-- Cause: create_household_invite called extensions.gen_random_bytes /
-- extensions.digest. On many projects pgcrypto is installed in `public`
-- (or only gen_random_uuid is available), so those qualified names 400.
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;

drop function if exists public.create_household_invite(uuid);

create or replace function public.create_household_invite(p_household_id uuid)
returns jsonb
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

  v_bytes := gen_random_bytes(10);
  for i in 0..9 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
  end loop;

  update public.household_invites as invites
     set expires_at = now()
   where invites.household_id = p_household_id
     and invites.used_at is null
     and invites.expires_at > now();

  insert into public.household_invites (household_id, created_by, token_hash, expires_at)
  values (p_household_id, v_uid, encode(digest(convert_to(v_code, 'UTF8'), 'sha256'), 'hex'), v_expires);

  return jsonb_build_object('code', v_code, 'expires_at', v_expires);
end;
$$;

revoke all on function public.create_household_invite(uuid) from public, anon;
grant execute on function public.create_household_invite(uuid) to authenticated;

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

  insert into public.profiles (id, display_name, email)
  select u.id,
         coalesce(nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''), split_part(coalesce(u.email, ''), '@', 1), 'Member'),
         u.email
  from auth.users u
  where u.id = v_uid
  on conflict (id) do nothing;

  select * into v_invite
  from public.household_invites
  where token_hash = encode(digest(convert_to(v_code, 'UTF8'), 'sha256'), 'hex')
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

notify pgrst, 'reload schema';
