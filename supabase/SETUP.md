# Supabase Setup

1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run [`schema.sql`](schema.sql).
3. Go to **Authentication → Users** and create one admin user (email + password).
4. Go to **Project Settings → API** and copy:
   - Project URL → `SUPABASE_URL`
   - `anon` public key → `SUPABASE_ANON_KEY`
   - `service_role` secret key → `SUPABASE_SERVICE_ROLE_KEY` (Vercel only, never in the app)

Use these values in Vercel environment variables when deploying the `api/` folder.
