-- =============================================================================
-- Joint Expenses – 0001 initial schema
-- Tables, constraints, indexes and data-integrity triggers.
-- Run with `supabase db push` or paste into the Supabase SQL editor in order.
-- =============================================================================

create extension if not exists "pgcrypto" with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.transaction_type as enum ('income', 'expense');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.member_role as enum ('owner', 'member');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- profiles – one row per auth user (created automatically by trigger)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null check (char_length(trim(display_name)) between 1 and 50),
  email         text,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- households
-- ---------------------------------------------------------------------------
create table if not exists public.households (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(trim(name)) between 1 and 60),
  owner_id    uuid not null references public.profiles (id) on delete restrict,
  currency    text not null default 'PHP' check (currency ~ '^[A-Z]{3}$'),
  created_at  timestamptz not null default now()
);

create index if not exists households_owner_idx on public.households (owner_id);

-- ---------------------------------------------------------------------------
-- household_members
-- ---------------------------------------------------------------------------
create table if not exists public.household_members (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  role          public.member_role not null default 'member',
  joined_at     timestamptz not null default now(),
  unique (household_id, user_id)
);

create index if not exists household_members_user_idx on public.household_members (user_id);

-- ---------------------------------------------------------------------------
-- categories – shared per household
-- ---------------------------------------------------------------------------
create table if not exists public.categories (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households (id) on delete cascade,
  name          text not null check (char_length(trim(name)) between 1 and 40),
  type          public.transaction_type not null,
  icon          text not null default 'category' check (char_length(icon) between 1 and 40),
  color         text not null default '#6366F1' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at    timestamptz not null default now()
);

create index if not exists categories_household_idx on public.categories (household_id);
create unique index if not exists categories_household_type_name_key
  on public.categories (household_id, type, lower(trim(name)));

-- ---------------------------------------------------------------------------
-- transactions – NUMERIC amounts, always positive; type decides the sign
-- ---------------------------------------------------------------------------
create table if not exists public.transactions (
  id                uuid primary key default gen_random_uuid(),
  household_id      uuid not null references public.households (id) on delete cascade,
  user_id           uuid not null references public.profiles (id) on delete cascade,
  type              public.transaction_type not null,
  amount            numeric(14, 2) not null check (amount > 0),
  category_id       uuid not null references public.categories (id) on delete restrict,
  description       text check (description is null or char_length(description) <= 200),
  transaction_date  date not null default current_date,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists transactions_household_date_idx
  on public.transactions (household_id, transaction_date desc, created_at desc);
create index if not exists transactions_category_idx on public.transactions (category_id);
create index if not exists transactions_user_idx on public.transactions (user_id);

-- ---------------------------------------------------------------------------
-- household_invites – only the SHA-256 hash of the invite code is stored
-- ---------------------------------------------------------------------------
create table if not exists public.household_invites (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references public.households (id) on delete cascade,
  created_by    uuid not null references public.profiles (id) on delete cascade,
  token_hash    text not null unique,
  expires_at    timestamptz not null,
  used_at       timestamptz,
  used_by       uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now()
);

create index if not exists household_invites_household_idx on public.household_invites (household_id);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- Keep updated_at fresh.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists transactions_set_updated_at on public.transactions;
create trigger transactions_set_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();

-- A transaction's category must belong to the same household and share its type.
create or replace function public.validate_transaction_category()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category record;
begin
  select household_id, type into v_category from public.categories where id = new.category_id;
  if not found then
    raise exception 'Category not found' using errcode = '23503';
  end if;
  if v_category.household_id <> new.household_id then
    raise exception 'Category belongs to a different household' using errcode = '23514';
  end if;
  if v_category.type <> new.type then
    raise exception 'Category type does not match the transaction type' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists transactions_validate_category on public.transactions;
create trigger transactions_validate_category
  before insert or update on public.transactions
  for each row execute function public.validate_transaction_category();

-- Prevent a household's owner from being reassigned by anyone but the owner.
create or replace function public.protect_household_owner()
returns trigger
language plpgsql
as $$
begin
  if new.owner_id <> old.owner_id and auth.uid() is distinct from old.owner_id then
    raise exception 'Only the owner can transfer a household' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists households_protect_owner on public.households;
create trigger households_protect_owner
  before update on public.households
  for each row execute function public.protect_household_owner();

-- Create a profile row for every new auth user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Member'
    ),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep the profile email in sync when the auth email changes.
create or replace function public.handle_user_email_updated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is distinct from old.email then
    update public.profiles set email = new.email where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row execute function public.handle_user_email_updated();
