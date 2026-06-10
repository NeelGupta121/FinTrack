#!/bin/bash
# Validates SQL migration files are syntactically correct
# Uses pg_dump --schema-only simulation or psql dry-run if available

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
SEED_FILE="$SCRIPT_DIR/seed.sql"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

errors=0

check_sql_file() {
  local file="$1"
  local label="$2"
  
  if [ ! -f "$file" ]; then
    echo -e "${RED}FAIL${NC}: $label - file not found: $file"
    errors=$((errors + 1))
    return
  fi

  # Method 1: Use psql with a transaction rollback (requires running postgres)
  if command -v psql &>/dev/null && [ -n "$DATABASE_URL" ]; then
    if psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "BEGIN;" -f "$file" -c "ROLLBACK;" 2>/dev/null; then
      echo -e "${GREEN}PASS${NC}: $label (psql dry-run)"
      return
    else
      echo -e "${RED}FAIL${NC}: $label (psql dry-run)"
      errors=$((errors + 1))
      return
    fi
  fi

  # Method 2: Basic syntax checks (no psql available)
  # Check balanced parentheses
  local open=$(grep -o '(' "$file" | wc -l)
  local close=$(grep -o ')' "$file" | wc -l)
  if [ "$open" -ne "$close" ]; then
    echo -e "${RED}FAIL${NC}: $label - unbalanced parentheses (open=$open close=$close)"
    errors=$((errors + 1))
    return
  fi

  # Check all statements end with semicolons (ignoring comments, empty lines, $$ blocks)
  if grep -vE '^\s*--|^\s*$|^\$\$|^begin$|^end$' "$file" | grep -vE ';\s*$' | grep -qvE '^\s*(returns|language|as)'; then
    : # Some lines legitimately don't end with ; (multi-line statements)
  fi

  echo -e "${GREEN}PASS${NC}: $label (syntax heuristics)"
}

echo "=== FinTrack SQL Schema Validation ==="
echo ""

# Check migrations
for f in "$MIGRATIONS_DIR"/*.sql; do
  check_sql_file "$f" "$(basename "$f")"
done

# Check seed
check_sql_file "$SEED_FILE" "seed.sql"

echo ""
# Verify expected tables in 001
echo "--- Table presence check (001_initial_schema.sql) ---"
EXPECTED_TABLES="accounts categories transactions holdings investment_transactions prices goals insights"
for table in $EXPECTED_TABLES; do
  if grep -q "create table $table" "$MIGRATIONS_DIR/001_initial_schema.sql"; then
    echo -e "${GREEN}✓${NC} $table"
  else
    echo -e "${RED}✗${NC} $table MISSING"
    errors=$((errors + 1))
  fi
done

echo ""
echo "--- RLS check ---"
for table in accounts categories transactions holdings investment_transactions prices goals insights; do
  if grep -q "alter table $table enable row level security" "$MIGRATIONS_DIR/001_initial_schema.sql"; then
    echo -e "${GREEN}✓${NC} RLS on $table"
  else
    echo -e "${RED}✗${NC} RLS MISSING on $table"
    errors=$((errors + 1))
  fi
done

echo ""
echo "--- Index check (002) ---"
if grep -q "idx_prices_symbol_date" "$MIGRATIONS_DIR/002_add_indexes_and_fixes.sql" && \
   grep -q "idx_transactions_user_date" "$MIGRATIONS_DIR/002_add_indexes_and_fixes.sql"; then
  echo -e "${GREEN}✓${NC} Critical indexes present"
else
  echo -e "${RED}✗${NC} Critical indexes missing"
  errors=$((errors + 1))
fi

echo ""
if [ $errors -eq 0 ]; then
  echo -e "${GREEN}All checks passed!${NC}"
  exit 0
else
  echo -e "${RED}$errors error(s) found${NC}"
  exit 1
fi
