-- Furniture Factory Management App - Supabase Schema
-- Run this in Supabase SQL Editor after creating your project.

-- Exchange rate (single row, admin updates anytime)
create table if not exists settings (
  id int primary key default 1 check (id = 1),
  usd_to_syp numeric not null default 15000,
  updated_at timestamptz default now()
);

insert into settings (id, usd_to_syp) values (1, 15000)
on conflict (id) do nothing;

-- Furniture catalog
create table if not exists items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cost numeric not null,
  sell_price numeric not null,
  currency text not null check (currency in ('SYP', 'USD')),
  created_at timestamptz default now()
);

-- Customers (each has a billing book)
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  address text,
  created_at timestamptz default now()
);

-- Bills (snapshot exchange rate at time of sale)
create table if not exists bills (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references customers(id),
  manual_customer_name text,
  manual_customer_phone text,
  bill_number serial,
  currency text not null check (currency in ('SYP', 'USD')),
  usd_to_syp_rate numeric not null,
  subtotal numeric not null,
  discount numeric not null default 0,
  total numeric not null,
  seller_signature text not null,
  created_at timestamptz default now()
);

-- Line items per bill (snapshot sell + cost at time of sale for profit reports)
create table if not exists bill_items (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid references bills(id) on delete cascade,
  item_id uuid references items(id),
  item_name text not null,
  quantity numeric not null default 1,
  unit_sell_price numeric not null,
  total_sell numeric not null,
  unit_item_cost numeric not null,
  total_item_cost numeric not null
);

create index if not exists idx_bills_created_at on bills(created_at);
create index if not exists idx_bills_customer_id on bills(customer_id);
create index if not exists idx_bill_items_bill_id on bill_items(bill_id);

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

-- Customer payments against a bill
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
