# FinTrack 💰

AI-powered investment & expense tracker. India-first, global-ready.

## Stack

- **Frontend**: Flutter (cross-platform)
- **Backend**: Supabase (auth, DB, realtime sync)
- **On-device AI**: TFLite (expense categorization)
- **Cloud AI**: Gemini Flash-Lite (sentiment, Q&A, portfolio review)
- **Market Data**: Alpha Vantage + Twelve Data (stocks), MFAPI.in (mutual funds)

## Architecture

Clean Architecture with 4 layers:

```
lib/
├── core/         # Config, DI, network, security, utils
├── data/         # Datasources, models, repository implementations
├── domain/       # Entities, repository contracts, use cases
├── presentation/ # UI (screens, widgets, state)
└── services/     # Platform services (SMS, notifications, background sync)
```

State management: Riverpod + code generation.

## Setup

```bash
# Prerequisites
flutter --version  # >= 3.3.0

# Install dependencies
flutter pub get

# Generate code (freezed, json_serializable, riverpod)
dart run build_runner build --delete-conflicting-outputs

# Run (provide Supabase credentials via dart-define)
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Tests
flutter test

# Build release APK
flutter build apk --obfuscate --split-debug-info=build/symbols
```

## API Keys Required

| Service | Free Tier | Get Key |
|---------|-----------|---------|
| Supabase | 50K rows, 500MB | supabase.com |
| Alpha Vantage | 25 calls/day | alphavantage.co |
| Twelve Data | 800 calls/day | twelvedata.com |
| NewsAPI | 100 calls/day | newsapi.org |
| Gemini | 1000 calls/day | ai.google.dev |

MFAPI.in and FRED require no API key.

## Cost

**$0/month** on all free tiers for MVP usage.

## License

MIT

## Secure AI Proxy (recommended for production)

The Gemini key must never ship in the client — mobile binaries are decompilable
and web bundles expose the network call. Route all Gemini traffic through the
`ai-proxy` Supabase Edge Function, which holds the key server-side, requires an
authenticated user, and enforces a per-user daily quota.

**Files**
- `supabase/functions/ai-proxy/index.ts` — the Edge Function (Deno/TypeScript)
- `supabase/migrations/004_ai_usage.sql` — per-user daily quota table + atomic RPC
- `lib/data/datasources/remote/ai_proxy_ds.dart` — dependency-free Dart client

**Deploy**
```bash
# 1. Apply the migration (adds ai_usage + increment_ai_usage)
supabase db push

# 2. Store the Gemini key as a server-side secret (never in the app)
supabase secrets set GEMINI_API_KEY=<your-gemini-key>
# Optional: override the default 100 requests/user/day
supabase secrets set AI_DAILY_LIMIT=100

# 3. Deploy the function (JWT verification stays ON)
supabase functions deploy ai-proxy
```

**Wire the client (prerequisite: Supabase auth)**

This app is currently local-only (Supabase and login were removed). To use the
proxy you must re-introduce a Supabase session:

1. Add the SDK: `flutter pub add supabase_flutter`
2. Initialize in `main()` and sign in. Anonymous sign-in preserves the
   "no login" UX while giving each install a real user id + JWT:
   ```dart
   await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
   await Supabase.instance.client.auth.signInAnonymously();
   ```
3. Replace the direct Gemini calls in `gemini_ds.dart` and `ai_chat_service.dart`
   with `AiProxyDatasource`, passing the session token:
   ```dart
   final token = Supabase.instance.client.auth.currentSession!.accessToken;
   final proxy = AiProxyDatasource(
     functionUrl: '${Env.supabaseUrl}/functions/v1/ai-proxy',
     anonKey: Env.supabaseAnonKey,
   );
   final answer = await proxy.askQuestion(token, question, context);
   ```
4. Drop `GEMINI_API_KEY` from the client build (`--dart-define`). It now lives
   only on the server, and you can rotate it without shipping a new app build.

## Securing the Gemini Key in Google Cloud

Whether the key is server-side (proxy) or — as an interim measure — in the
client build, restrict and cap it in the Google Cloud / AI Studio console.
Defense in depth against leaks and runaway billing:

1. **Restrict the API** — APIs & Services → Credentials → your key → *API
   restrictions* → restrict to **Generative Language API** only, so a leaked key
   can't be used against other Google APIs.
2. **Application restrictions**
   - *Server-side (proxy):* "None" is acceptable since the key never leaves the
     server; prefer an IP allowlist if your egress IPs are known.
   - *Client-side (interim):* set Android app restrictions (package name +
     SHA-1) and, for web, HTTP referrer restrictions. These raise the bar but
     are bypassable — they are **not** a substitute for the proxy.
3. **Cap the quota** — APIs & Services → Generative Language API → *Quotas* →
   set requests-per-minute / per-day limits so a leak can't run up unbounded
   cost. Pair with a billing budget + alert (Billing → Budgets & alerts).
4. **Monitor** — enable API metrics and alert on anomalous request volume.
5. **Rotate** — with the proxy, rotate any time via
   `supabase secrets set GEMINI_API_KEY=<new>` with no app release.
