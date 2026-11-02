-- =============================================================================
-- Mode of payment on transactions.
-- Manual expenses default to cash. BPI / credit-card statement imports use cc.
-- =============================================================================

do $$ begin
  create type public.payment_method as enum (
    'cash', 'cc', 'gcash', 'maya', 'seabank', 'other'
  );
exception when duplicate_object then null; end $$;

alter table public.transactions
  add column if not exists payment_method public.payment_method not null default 'cash';

update public.transactions
   set payment_method = 'cc'
 where source_type = 'credit_card_statement'
   and payment_method = 'cash';

create or replace function public.apply_statement_payment_method()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT'
     and new.source_type = 'credit_card_statement'
     and new.payment_method = 'cash' then
    new.payment_method := 'cc';
  end if;
  return new;
end;
$$;

drop trigger if exists transactions_apply_statement_mop on public.transactions;
create trigger transactions_apply_statement_mop
  before insert on public.transactions
  for each row
  execute function public.apply_statement_payment_method();
