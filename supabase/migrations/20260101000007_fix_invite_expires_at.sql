-- =============================================================================
-- Fix: column reference "expires_at" is ambiguous
-- RETURNS TABLE (expires_at ...) created a PL/pgSQL variable that clashed with
-- household_invites.expires_at. Return jsonb instead and qualify table columns.
-- Paste this into the Supabase SQL Editor and Run, then retry Invite in the app.
-- =============================================================================

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

notify pgrst, 'reload schema';
