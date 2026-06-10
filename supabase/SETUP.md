# FinTrack Supabase Setup Guide

## 1. Create Project

1. Go to [supabase.com](https://supabase.com) and sign up (free tier)
2. Click **New Project**
3. Name: `fintrack`, Region: closest to you, DB password: save it securely
4. Wait ~2 min for provisioning

## 2. Get Credentials

1. Go to **Settings → API**
2. Copy:
   - **Project URL** (e.g. `https://abc123.supabase.co`)
   - **anon/public key** (safe for client-side)
   - **service_role key** (admin — never expose in client)

## 3. Run Migrations

### Option A: SQL Editor (quickest)

1. Go to **SQL Editor** in Supabase dashboard
2. Paste contents of `migrations/001_initial_schema.sql` → Run
3. Paste contents of `migrations/002_add_indexes_and_fixes.sql` → Run

### Option B: Supabase CLI

```bash
npm install -g supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

### Option C: deploy.sh script

```bash
chmod +x deploy.sh
./deploy.sh <PROJECT_URL> <SERVICE_ROLE_KEY>
```

## 4. Seed Data

Paste `seed.sql` in the SQL Editor and run. This inserts 23 default categories.

## 5. Set Up Auth

1. Go to **Authentication → Providers**
2. **Email**: Already enabled by default
3. **Google OAuth**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Create OAuth 2.0 Client ID (Web application)
   - Authorized redirect URI: `https://<your-project>.supabase.co/auth/v1/callback`
   - Copy Client ID + Secret into Supabase Google provider settings
   - Enable the provider

## 6. RLS (Already Configured)

Row Level Security is enabled in the migrations. Each table has policies ensuring users can only access their own data. No action needed.

## 7. Configure Flutter App

Create `.env` in the fintrack root (copy from `.env.example`):

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
NEWS_API_KEY=your-newsapi-key
GEMINI_API_KEY=your-gemini-key
ALPHA_VANTAGE_KEY=your-alpha-vantage-key
```

The app reads these via `flutter_dotenv`.

## 8. Test Connection

```bash
curl -s "https://<your-project>.supabase.co/rest/v1/categories?select=count" \
  -H "apikey: <anon-key>" \
  -H "Authorization: Bearer <anon-key>"
```

Expected: `[{"count":23}]` (after seeding).

## Verify Schema

```bash
chmod +x check_schema.sh
./check_schema.sh <PROJECT_URL> <SERVICE_ROLE_KEY>
```
