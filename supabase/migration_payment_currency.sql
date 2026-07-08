-- Run in Supabase → SQL Editor
-- Lets a payment be recorded in SYP or USD independently of the bill currency.
-- `amount` stays in the bill's currency (for totals); `original_amount` +
-- `payment_currency` capture what the admin actually entered.

alter table bill_payments
  add column if not exists payment_currency text;

alter table bill_payments
  add column if not exists original_amount numeric;

-- Backfill existing rows: assume they were entered in the bill's currency.
update bill_payments p
set payment_currency = b.currency,
    original_amount = p.amount
from bills b
where p.bill_id = b.id
  and p.payment_currency is null;
