-- Employees module: workers, attendance timer sessions, and loans.
-- Run this in the Supabase SQL Editor.

-- Workers. The admin enters a weekly salary; the per-minute rate is derived
-- from it (weekly_salary / 3240 => 9h x 6 days).
create table if not exists employees (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  weekly_salary numeric not null default 0 check (weekly_salary >= 0),
  currency text not null default 'SYP' check (currency in ('SYP', 'USD')),
  active boolean not null default true,
  created_at timestamptz default now()
);

-- Attendance sessions. A row with end_at = null means the timer is running.
create table if not exists work_sessions (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  start_at timestamptz not null default now(),
  end_at timestamptz,
  created_at timestamptz default now()
);

-- Loans given to a worker; deducted from the net salary of the week they fall in.
create table if not exists employee_loans (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  amount numeric not null check (amount > 0),
  note text,
  loan_date timestamptz not null default now(),
  created_at timestamptz default now()
);

create index if not exists idx_work_sessions_employee on work_sessions(employee_id, start_at);
create index if not exists idx_employee_loans_employee on employee_loans(employee_id, loan_date);
