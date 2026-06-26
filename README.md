# DAAS App - Furniture Factory Management

Arabic RTL Android app for managing a furniture factory: items, customers, billing, PDF invoices, exchange rate, and profit reports.

## Stack

- **Flutter** (Android) — mobile client
- **Next.js API** (`api/`) — backend on Vercel
- **Supabase** — PostgreSQL database + admin auth

## Quick start

1. Set up Supabase: [supabase/SETUP.md](supabase/SETUP.md)
2. Run API locally: see [DEPLOY.md](DEPLOY.md)
3. Run the app:

```bash
flutter pub get
flutter run
```

For a physical device or production API:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.vercel.app
```

## Features

- Admin login (single account via Supabase Auth)
- Items catalog (name, cost, sell price, SYP/USD)
- USD → SYP exchange rate
- Customers with billing book history
- Create bills with signature, print/share PDF
- Monthly and yearly profit reports (sales − product cost)
