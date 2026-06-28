-- Run in Supabase → SQL Editor
-- Adds bill discount and customer address

alter table customers add column if not exists address text;

alter table bills add column if not exists discount numeric not null default 0;
