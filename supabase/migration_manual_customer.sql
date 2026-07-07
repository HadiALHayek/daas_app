-- Run in Supabase → SQL Editor
-- Adds manual customer fields for direct pay (walk-in) bills

alter table bills add column if not exists manual_customer_name text;
alter table bills add column if not exists manual_customer_phone text;
