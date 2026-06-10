#!/bin/bash
# Validate FinTrack schema on a deployed Supabase project
# Usage: ./check_schema.sh <SUPABASE_URL> <SERVICE_ROLE_KEY>
set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <SUPABASE_URL> <SERVICE_ROLE_KEY>"
  exit 1
fi

URL="$1"
KEY="$2"
PASS=0
FAIL=0

check() {
  local label="$1" query="$2" expect="$3"
  local result=$(curl -s "${URL}/rest/v1/rpc/exec_sql" \
    -H "apikey: ${KEY}" \
    -H "Authorization: Bearer ${KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"query\": $(echo "$query" | jq -Rs .)}" 2>&1)
  
  if echo "$result" | grep -qi "$expect"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "🔍 Checking FinTrack schema at: $URL"
echo ""

# Check tables exist
echo "📋 Tables (expect 8):"
TABLES="accounts categories transactions budgets holdings investments_history recurring_transactions user_settings"
for t in $TABLES; do
  check "$t" "SELECT to_json(t) FROM (SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename='$t') t" "$t"
done

echo ""
echo "🔒 Row Level Security:"
for t in $TABLES; do
  check "RLS on $t" "SELECT to_json(t) FROM (SELECT relrowsecurity FROM pg_class WHERE relname='$t') t" "true"
done

echo ""
echo "📇 Indexes:"
INDEX_QUERY="SELECT count(*) as cnt FROM pg_indexes WHERE schemaname='public'"
result=$(curl -s "${URL}/rest/v1/rpc/exec_sql" \
  -H "apikey: ${KEY}" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"query\": $(echo "$INDEX_QUERY" | jq -Rs .)}" 2>&1)
echo "  Indexes found: $(echo "$result" | grep -oP '\d+' | head -1 || echo 'unknown')"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && echo "✅ Schema is healthy!" || echo "⚠️  Issues detected."
exit $FAIL
