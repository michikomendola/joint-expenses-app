-- =============================================================================
-- Paid marker for joint expenses. Null means unpaid. Personal rows stay null.
-- =============================================================================

alter table public.transactions
  add column if not exists joint_paid_at timestamptz;

create or replace function public.clear_joint_paid_unless_joint()
returns trigger
language plpgsql
as $$
begin
  if new.type <> 'expense' or new.expense_scope <> 'joint' then
    new.joint_paid_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists transactions_clear_joint_paid on public.transactions;
create trigger transactions_clear_joint_paid
  before insert or update on public.transactions
  for each row
  execute function public.clear_joint_paid_unless_joint();

alter table public.transactions
  drop constraint if exists transactions_joint_paid_chk;
alter table public.transactions
  add constraint transactions_joint_paid_chk check (
    joint_paid_at is null
    or (type = 'expense' and expense_scope = 'joint')
  );
