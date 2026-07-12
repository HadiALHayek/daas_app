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

-- Manual per-day salary overrides. When present for a given day, this amount
-- replaces the computed pay for that day (in the daily and weekly reports).
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

-- Records a week's salary payout for an employee. Each payout also creates a
-- matching row in expense_payments (category 'labor') so it shows up as an
-- expense in the profit report. week_start is the Saturday (local) of the week.
create table if not exists salary_payments (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  week_start date not null,
  gross numeric not null default 0,
  loans numeric not null default 0,
  net numeric not null default 0,
  amount numeric not null default 0,
  usd_to_syp_rate numeric not null,
  expense_payment_id uuid references expense_payments(id) on delete set null,
  paid_at timestamptz not null default now(),
  created_at timestamptz default now(),
  unique (employee_id, week_start)
);

create index if not exists idx_salary_payments_week on salary_payments(week_start);
