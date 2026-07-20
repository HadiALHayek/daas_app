# Supabase Setup

1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run [`schema.sql`](schema.sql).
3. If the project already existed before payments were added, also run [`migration_payments.sql`](migration_payments.sql).
4. If you need bill discounts and customer addresses, run [`migration_bill_discount_address.sql`](migration_bill_discount_address.sql).
5. If the employees module already existed before salary-rate history, run [`migration_employee_salary_rates.sql`](migration_employee_salary_rates.sql) (keeps old salaries when you edit a worker's weekly salary).
6. If daily salary overrides are needed, run [`migration_daily_salary_overrides.sql`](migration_daily_salary_overrides.sql).
7. To clear worker loans on payday (while keeping them on that week's salary table), run [`migration_loan_settlement.sql`](migration_loan_settlement.sql).
8. Go to **Authentication → Users** and create one admin user (email + password).
9. Go to **Project Settings → API** and copy:
   - Project URL → `SUPABASE_URL`
   - `anon` public key → `SUPABASE_ANON_KEY`
   - `service_role` secret key → `SUPABASE_SERVICE_ROLE_KEY` (Vercel only, never in the app)

Use these values in Vercel environment variables when deploying the `api/` folder.
