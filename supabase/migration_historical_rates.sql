-- Add exchange rate column to payments to track historical values
-- This ensures that reports remain accurate even if the current exchange rate changes.

-- 1. Update bill_payments table
alter table bill_payments
add column if not exists usd_to_syp_rate numeric;

-- Backfill existing payments with the rate from their parent bill
update bill_payments p
set usd_to_syp_rate = b.usd_to_syp_rate
from bills b
where p.bill_id = b.id and p.usd_to_syp_rate is null;

-- 2. Update expense_payments table
alter table expense_payments
add column if not exists usd_to_syp_rate numeric;

-- Backfill existing expenses with the current rate (best guess)
update expense_payments
set usd_to_syp_rate = (select usd_to_syp from settings where id = 1 limit 1)
where usd_to_syp_rate is null;
