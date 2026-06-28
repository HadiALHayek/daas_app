-- Run this in Supabase → SQL Editor (New query → Run)
-- Creates: expense_payments, bill_payments
-- Table name is expense_payments (NOT "expences" or "expenses")

-- Operational expenses (materials, transport, labor, etc.)
create table if not exists expense_payments (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null check (category in ('materials', 'transport', 'labor', 'other')),
  amount numeric not null check (amount > 0),
  currency text not null check (currency in ('SYP', 'USD')),
  notes text,
  payment_date timestamptz not null default now(),
  created_at timestamptz default now()
);

-- Customer payments against a bill (partial or full)
create table if not exists bill_payments (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references bills(id) on delete cascade,
  amount numeric not null check (amount > 0),
  notes text,
  payment_date timestamptz not null default now(),
  created_at timestamptz default now()
);

create index if not exists idx_expense_payments_date on expense_payments(payment_date);
create index if not exists idx_bill_payments_bill_id on bill_payments(bill_id);
