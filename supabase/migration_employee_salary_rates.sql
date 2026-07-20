-- Migration: soft-delete-safe salary history + backfill rates.
-- Run this in the Supabase SQL Editor.
--
-- 1) Historical weekly salary rates so editing a worker's salary does not
--    rewrite past weeks' pay (new rate applies from the current week onward).
-- 2) Backfill one rate per existing employee so past weeks keep their current
--    stored salary until the next edit.

create table if not exists employee_salary_rates (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  weekly_salary numeric not null check (weekly_salary >= 0),
  effective_from date not null,
  created_at timestamptz default now(),
  unique (employee_id, effective_from)
);

create index if not exists idx_employee_salary_rates_emp
  on employee_salary_rates(employee_id, effective_from desc);

insert into employee_salary_rates (employee_id, weekly_salary, effective_from)
select id, weekly_salary, date '2000-01-01'
from employees
on conflict (employee_id, effective_from) do nothing;
