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
