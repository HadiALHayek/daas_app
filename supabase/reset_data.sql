-- ⚠️  DANGER: wipes all transactional data so you can start fresh.
-- Run in Supabase → SQL Editor. This CANNOT be undone — export a backup first
-- if you might need the data later.
--
-- What it does:
--   • Deletes all bills, their line items, and their payments
--   • Deletes all customers
--   • Deletes all expenses
--   • Resets the bill number counter back to 1
--   • KEEPS your items catalog and your exchange-rate setting
--
-- TRUNCATE ... CASCADE also clears bill_items + bill_payments automatically
-- (they reference bills), and RESTART IDENTITY resets the bill_number serial.

truncate table
  bill_payments,
  bill_items,
  bills,
  expense_payments,
  customers
restart identity cascade;

-- ─────────────────────────────────────────────────────────────────────────
-- OPTIONAL: also wipe the furniture catalog (items). Uncomment to include it.
-- truncate table items restart identity cascade;
--
-- OPTIONAL: reset the exchange rate back to the default 15000.
-- update settings set usd_to_syp = 15000, updated_at = now() where id = 1;
-- ─────────────────────────────────────────────────────────────────────────
