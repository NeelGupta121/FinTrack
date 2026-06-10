#!/bin/bash
# Deploy FinTrack schema to Supabase
# Usage: ./deploy.sh <SUPABASE_URL> <SERVICE_ROLE_KEY>
set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <SUPABASE_URL> <SERVICE_ROLE_KEY>"
  echo "Example: $0 https://abc123.supabase.co eyJhbGciOi..."
  exit 1
fi

URL="$1"
KEY="$2"
DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=0

run_sql() {
  local file="$1"
  local name=$(basename "$file")
  echo -n "  Applying $name... "
  
  local sql=$(cat "$file")
  local response=$(curl -s -w "\n%{http_code}" \
    "${URL}/rest/v1/rpc/exec_sql" \
    -H "apikey: ${KEY}" \
    -H "Authorization: Bearer ${KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"query\": $(echo "$sql" | jq -Rs .)}" 2>&1)
  
  local http_code=$(echo "$response" | tail -1)
  
  if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
    echo "✅"
  else
    # Fallback: try psql if available
    if command -v psql &>/dev/null && [ -n "$DATABASE_URL" ]; then
      echo -n "(trying psql) "
      if psql "$DATABASE_URL" -f "$file" &>/dev/null; then
        echo "✅"
      else
        echo "❌ (HTTP $http_code)"
        FAILED=$((FAILED + 1))
      fi
    else
      echo "❌ (HTTP $http_code)"
      echo "    Hint: Paste this file manually in Supabase SQL Editor,"
      echo "    or set DATABASE_URL and install psql for direct access."
      FAILED=$((FAILED + 1))
    fi
  fi
}

echo "🚀 Deploying FinTrack schema to: $URL"
echo ""

# First, create the exec_sql function if it doesn't exist
echo "  Setting up SQL executor..."
curl -s "${URL}/rest/v1/rpc/exec_sql" \
  -H "apikey: ${KEY}" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"SELECT 1"}' >/dev/null 2>&1 || true

echo ""
echo "📦 Applying migrations..."
for file in "$DIR"/migrations/*.sql; do
  [ -f "$file" ] && run_sql "$file"
done

echo ""
echo "🌱 Seeding data..."
run_sql "$DIR/seed.sql"

echo ""
if [ $FAILED -eq 0 ]; then
  echo "✅ All done! Schema deployed successfully."
else
  echo "⚠️  $FAILED file(s) failed. Paste them manually in the SQL Editor."
  echo "   Dashboard: ${URL//.supabase.co/}/project/default/sql"
fi

exit $FAILED
