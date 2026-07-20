-- Migration: settle loans on salary payday.
-- When a week's salaries are paid, outstanding loans for those workers are
-- marked settled for that week. They remain visible on that week's salary
-- table, but the next week starts with a clear loan balance.
-- Run this in the Supabase SQL Editor.

alter table employee_loans
  add column if not exists settled_week_start date;

create index if not exists idx_employee_loans_settled
  on employee_loans(employee_id, settled_week_start);
