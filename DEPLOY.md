# Deployment Guide

## 1. Supabase

Follow [supabase/SETUP.md](supabase/SETUP.md):
- Run `supabase/schema.sql`
- Create admin user in Authentication

## 2. Vercel API

1. Push this repository to GitHub.
2. Import the project in [Vercel](https://vercel.com).
3. Set **Root Directory** to `api`.
4. Add environment variables:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
5. Deploy and copy your API URL (e.g. `https://your-app.vercel.app`).

### Local API development

```bash
cd api
cp .env.example .env
# Edit .env with your Supabase keys
npm install
npm run dev
```

API runs at `http://localhost:3000`.

## 3. Flutter Android APK

### Emulator (API on host machine)

Default API URL is `http://10.0.2.2:3000` (Android emulator → host localhost).

### Physical device or production

Build with your Vercel URL:

```bash
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://your-app.vercel.app
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

### Run in debug

```bash
flutter run --dart-define=API_BASE_URL=https://your-app.vercel.app
```

## 4. First login

Use the email and password of the admin user you created in Supabase Authentication.
