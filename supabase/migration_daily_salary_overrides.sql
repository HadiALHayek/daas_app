-- Migration: per-day salary overrides.
-- Lets the admin manually set a worker's salary for a specific day; this amount
-- then replaces the computed pay for that day in the daily and weekly reports.
-- Run this in the Supabase SQL Editor.

create table if not exists daily_salary_overrides (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  work_date date not null,
  amount numeric not null check (amount >= 0),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (employee_id, work_date)
);

create index if not exists idx_daily_salary_overrides_emp
  on daily_salary_overrides(employee_id, work_date);
