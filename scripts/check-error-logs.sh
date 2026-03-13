#!/bin/bash
# Check runtime error logs for outstanding issues.
#
# Runs WITHOUT Flutter — pure bash + python3. Safe for CI, pre-commit, or manual use.
#
# Usage:
#   ./scripts/check-error-logs.sh              # Report outstanding errors
#   ./scripts/check-error-logs.sh --summary    # One-line summary only
#   ./scripts/check-error-logs.sh --clear      # Clear the log after review

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/logs/runtime-errors.jsonl"

MODE="${1:-report}"

# Check if log file exists and has content
if [ ! -f "$LOG_FILE" ]; then
    echo "  No error log file found at logs/runtime-errors.jsonl"
    exit 0
fi

LINE_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
if [ "$LINE_COUNT" -eq 0 ] || [ ! -s "$LOG_FILE" ]; then
    echo "  Error log is empty — no outstanding issues."
    exit 0
fi

# Summarize errors using python3
SUMMARY=$(python3 -c "
import json, sys, collections

log_path = '$LOG_FILE'
errors = []
with open(log_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            errors.append(json.loads(line))
        except:
            pass

if not errors:
    print('  Error log is empty — no outstanding issues.')
    sys.exit(0)

# Deduplicate by error message prefix
groups = collections.Counter()
severity_map = {}
version_map = {}
date_map = {}
for e in errors:
    msg = e.get('error', '')[:100].split('\n')[0]
    groups[msg] += 1
    sev = e.get('severity', 'unknown')
    ver = e.get('appVersion', '?')
    ts = e.get('timestamp', '?')[:10]
    # Keep highest severity
    if msg not in severity_map or sev == 'critical':
        severity_map[msg] = sev
    version_map[msg] = ver
    date_map[msg] = ts

critical_count = sum(1 for s in severity_map.values() if s == 'critical')
error_count = sum(1 for s in severity_map.values() if s == 'error')

if '$MODE' == '--summary':
    print(f'  Error log: {len(errors)} entries ({critical_count} critical, {error_count} error, {len(groups)} unique)')
    sys.exit(0)

print(f'  Outstanding runtime errors: {len(errors)} entries, {len(groups)} unique types')
print()
for msg, count in groups.most_common():
    sev = severity_map[msg]
    ver = version_map[msg]
    ts = date_map[msg]
    icon = 'CRITICAL' if sev == 'critical' else 'ERROR' if sev == 'error' else 'WARN'
    print(f'  [{icon}] ({count}x) {ver} {ts} — {msg[:90]}')
print()
print(f'  Action required: Review errors above. Fix bugs, then clear with:')
print(f'    ./scripts/check-error-logs.sh --clear')

if critical_count > 0:
    sys.exit(2)
" 2>&1) || EXIT_CODE=$?

EXIT_CODE=${EXIT_CODE:-0}

echo "$SUMMARY"

if [ "$MODE" = "--clear" ]; then
    echo ""
    echo "  Clearing error log..."
    : > "$LOG_FILE"
    echo "  Error log cleared."
    exit 0
fi

# In hook mode, warn but don't block (exit 0)
# Critical errors print a visible warning but allow the commit
if [ "$EXIT_CODE" -eq 2 ]; then
    echo ""
    echo "  WARNING: Critical runtime errors exist in logs/runtime-errors.jsonl"
    echo "  Review and fix these before your next release."
fi

exit 0
