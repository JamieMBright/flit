#!/usr/bin/env bash
# =============================================================================
# Flit — Supabase Schema Rebuild Runner
# =============================================================================
# Usage:
#   ./scripts/rebuild-supabase.sh              # Apply rebuild.sql (safe, idempotent)
#   ./scripts/rebuild-supabase.sh --verify     # Run verify.sql only
#   ./scripts/rebuild-supabase.sh --teardown   # NUKE everything, then rebuild
#   ./scripts/rebuild-supabase.sh --full       # Teardown + rebuild + verify
#
# Requires:
#   SUPABASE_DB_URL  — Postgres connection string (from Supabase dashboard > Settings > Database)
#                      Format: postgresql://postgres.[project-ref]:[password]@[host]:5432/postgres
#
# If psql is not available, copy the SQL files into the Supabase SQL Editor instead.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REBUILD_SQL="$PROJECT_DIR/supabase/rebuild.sql"
VERIFY_SQL="$PROJECT_DIR/supabase/verify.sql"
TEARDOWN_SQL="$PROJECT_DIR/supabase/teardown.sql"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo -e "${RED}Error: SUPABASE_DB_URL is not set.${NC}"
  echo ""
  echo "Set it from the Supabase dashboard:"
  echo "  Project Settings > Database > Connection string > URI"
  echo ""
  echo "  export SUPABASE_DB_URL='postgresql://postgres.[ref]:[password]@[host]:5432/postgres'"
  echo ""
  echo "Alternatively, copy these files into the Supabase SQL Editor:"
  echo "  1. supabase/teardown.sql  (optional — nuclear reset)"
  echo "  2. supabase/rebuild.sql   (creates/fixes all tables)"
  echo "  3. supabase/verify.sql    (checks everything is correct)"
  exit 1
fi

if ! command -v psql &> /dev/null; then
  echo -e "${YELLOW}Warning: psql not found. Install PostgreSQL client or use the Supabase SQL Editor.${NC}"
  echo ""
  echo "On macOS:  brew install libpq && brew link --force libpq"
  echo "On Linux:  sudo apt-get install postgresql-client"
  echo ""
  echo "SQL files to run manually:"
  echo "  1. supabase/rebuild.sql"
  echo "  2. supabase/verify.sql"
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

MODE="rebuild"  # default
case "${1:-}" in
  --verify)   MODE="verify" ;;
  --teardown) MODE="teardown" ;;
  --full)     MODE="full" ;;
  --help|-h)
    echo "Usage: $0 [--verify | --teardown | --full]"
    echo ""
    echo "  (default)    Run rebuild.sql (safe, idempotent)"
    echo "  --verify     Run verify.sql only (check schema)"
    echo "  --teardown   DESTRUCTIVE: drop all tables, then rebuild"
    echo "  --full       Teardown + rebuild + verify"
    exit 0
    ;;
  "")         MODE="rebuild" ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    echo "Usage: $0 [--verify | --teardown | --full]"
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------

run_sql() {
  local label="$1"
  local file="$2"
  echo -e "${YELLOW}Running $label...${NC}"
  echo "  File: $file"
  if psql "$SUPABASE_DB_URL" -f "$file" 2>&1; then
    echo -e "${GREEN}$label completed successfully.${NC}"
  else
    echo -e "${RED}$label failed. Check the output above.${NC}"
    exit 1
  fi
  echo ""
}

case "$MODE" in
  rebuild)
    run_sql "rebuild.sql" "$REBUILD_SQL"
    echo -e "${GREEN}Done. Run with --verify to check the schema.${NC}"
    ;;
  verify)
    run_sql "verify.sql" "$VERIFY_SQL"
    ;;
  teardown)
    echo -e "${RED}WARNING: This will DELETE ALL DATA from all Flit tables.${NC}"
    echo -n "Type 'yes' to confirm: "
    read -r confirm
    if [ "$confirm" != "yes" ]; then
      echo "Aborted."
      exit 0
    fi
    run_sql "teardown.sql" "$TEARDOWN_SQL"
    run_sql "rebuild.sql" "$REBUILD_SQL"
    echo -e "${GREEN}Teardown + rebuild complete. Run with --verify to check.${NC}"
    ;;
  full)
    echo -e "${RED}WARNING: This will DELETE ALL DATA from all Flit tables.${NC}"
    echo -n "Type 'yes' to confirm: "
    read -r confirm
    if [ "$confirm" != "yes" ]; then
      echo "Aborted."
      exit 0
    fi
    run_sql "teardown.sql" "$TEARDOWN_SQL"
    run_sql "rebuild.sql" "$REBUILD_SQL"
    run_sql "verify.sql" "$VERIFY_SQL"
    echo -e "${GREEN}Full rebuild + verify complete.${NC}"
    ;;
esac
