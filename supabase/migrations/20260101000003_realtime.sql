-- =============================================================================
-- Joint Expenses – 0004 realtime
-- Publishes household tables through Supabase Realtime. RLS still applies to
-- every change event, so members only receive rows they are allowed to read.
-- REPLICA IDENTITY FULL is required so DELETE events carry household_id and
-- therefore pass the client-side household filter.
-- =============================================================================

alter table public.transactions      replica identity full;
alter table public.categories        replica identity full;
alter table public.household_members replica identity full;
alter table public.households        replica identity full;

do $$
declare
  t text;
begin
  foreach t in array array['transactions', 'categories', 'household_members', 'households'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end;
$$;
