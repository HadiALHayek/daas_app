-- Run this ONLY if bill creation fails with column errors on bill_items.
-- It upgrades an older schema to the current profit-tracking columns.

alter table bill_items add column if not exists item_id uuid references items(id);
alter table bill_items add column if not exists unit_sell_price numeric;
alter table bill_items add column if not exists total_sell numeric;
alter table bill_items add column if not exists unit_item_cost numeric;
alter table bill_items add column if not exists total_item_cost numeric;

-- If you had old unit_cost / total_cost columns, copy them then drop:
-- update bill_items set unit_sell_price = unit_cost, total_sell = total_cost where unit_sell_price is null;
-- alter table bill_items drop column if exists unit_cost;
-- alter table bill_items drop column if exists total_cost;

alter table bill_items alter column unit_sell_price set not null;
alter table bill_items alter column total_sell set not null;
alter table bill_items alter column unit_item_cost set not null;
alter table bill_items alter column total_item_cost set not null;
