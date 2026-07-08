-- Run in Supabase → SQL Editor
-- Records the USD→SYP exchange rate in effect at the moment each payment was made.

alter table bill_payments
  add column if not exists usd_to_syp_rate numeric;
