#!/usr/bin/env bash
#
# FinTrack dev run helper.
# Loads keys from .env and passes them to `flutter run` as --dart-define,
# so you never hand-type keys. The app entrypoint is lib/main.dart (default).
#
# Usage:
#   ./run.sh                 # run on the default device (debug)
#   ./run.sh -d <deviceId>   # target a specific device / emulator
#   ./run.sh --release       # release-mode run
#   ./run.sh --profile       # profile-mode run
#
# SECURITY: only client-safe keys are passed. SUPABASE_SERVICE_ROLE_KEY is a
# SERVER secret and is intentionally NEVER sent to the app. Key VALUES are not
# printed (only key names), so they don't leak into terminal history/logs.
set -euo pipefail
cd "$(dirname "$0")"

command -v flutter >/dev/null 2>&1 || { echo "error: 'flutter' is not on your PATH"; exit 1; }

# Client-safe keys only.
KEYS=(GEMINI_API_KEY ALPHA_VANTAGE_KEY TWELVE_DATA_KEY NEWS_API_KEY FRED_API_KEY SUPABASE_URL SUPABASE_ANON_KEY)

if [[ -f .env ]]; then
  echo "Loading .env"
  set -a
  # shellcheck disable=SC1091
  source ./.env
  set +a
else
  echo "warn: no .env found. Run: cp .env.example .env  and fill in your keys."
  echo "      Continuing with empty keys — AI / market-data features will be limited."
fi

DEFINES=()
SET_KEYS=()
for k in "${KEYS[@]}"; do
  v="${!k:-}"
  if [[ -n "$v" ]]; then
    DEFINES+=("--dart-define=$k=$v")
    SET_KEYS+=("$k")
  fi
done

echo "Starting: flutter run  (${#DEFINES[@]} key(s): ${SET_KEYS[*]:-none})"
exec flutter run "${DEFINES[@]}" "$@"
