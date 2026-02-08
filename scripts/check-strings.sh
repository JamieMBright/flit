#!/bin/bash
# Check Dart files for common string literal issues.
#
# Runs WITHOUT Flutter — pure bash + grep. Safe for CI, pre-commit, or manual use.
#
# Usage:
#   ./scripts/check-strings.sh              # Scan all Dart files in lib/
#   ./scripts/check-strings.sh lib/game/     # Scan a specific directory
#   ./scripts/check-strings.sh --staged      # Scan only git-staged Dart files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Determine which files to scan.
if [ "${1:-}" = "--staged" ]; then
    FILES=$(cd "$PROJECT_ROOT" && git diff --cached --name-only --diff-filter=ACM -- '*.dart' || true)
    LABEL="staged Dart files"
elif [ -n "${1:-}" ]; then
    FILES=$(find "$PROJECT_ROOT/$1" -name '*.dart' -type f 2>/dev/null || true)
    LABEL="Dart files in $1"
else
    FILES=$(find "$PROJECT_ROOT/lib" -name '*.dart' -type f 2>/dev/null || true)
    LABEL="all Dart files in lib/"
fi

if [ -z "$FILES" ]; then
    echo "No files to scan."
    exit 0
fi

echo "Scanning $LABEL for string literal issues..."
echo ""

TOTAL_ERRORS=0
TOTAL_WARNINGS=0

for file in $FILES; do
    # Resolve path relative to project root for display.
    [ -f "$file" ] || continue
    REL_PATH="${file#$PROJECT_ROOT/}"

    # ---- Check 1: \\' pattern (escaped backslash + bare quote) ----
    # This is the #1 codegen bug: Python's \\\' produces \\' in output,
    # which Dart reads as escaped-backslash + string-terminator.
    # Skip raw strings (r'...' / r"...") since they have different rules.
    MATCHES=$(grep -nP "(?<!r)(?<!r\")'\S*\\\\\\\\'" "$file" 2>/dev/null || true)
    if [ -n "$MATCHES" ]; then
        while IFS= read -r line; do
            LINENUM=$(echo "$line" | cut -d: -f1)
            LINETEXT=$(echo "$line" | cut -d: -f2-)
            # Skip lines that are raw strings or comments.
            if echo "$LINETEXT" | grep -qP '^\s*//' 2>/dev/null; then continue; fi
            if echo "$LINETEXT" | grep -qP "r['\"]" 2>/dev/null; then continue; fi
            echo "  ERROR  $REL_PATH:$LINENUM: broken escape (\\\\') — use double quotes or proper escaping"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        done <<< "$MATCHES"
    fi

    # ---- Check 2: Unescaped apostrophe in single-quoted string ----
    # Heuristic: 'text'text' where apostrophe is between word characters.
    # This catches things like: 'St. John's' (which should be "St. John's")
    MATCHES=$(grep -nP "'[^'\\\\]*[a-zA-Z]'[a-zA-Z]" "$file" 2>/dev/null || true)
    if [ -n "$MATCHES" ]; then
        while IFS= read -r line; do
            LINENUM=$(echo "$line" | cut -d: -f1)
            LINETEXT=$(echo "$line" | cut -d: -f2-)
            # Skip full-line comments.
            if echo "$LINETEXT" | grep -qP '^\s*//' 2>/dev/null; then continue; fi
            # Skip lines where the apostrophe is inside a double-quoted string.
            # This handles: capital: "St. George's" — the 's" part triggers
            # the pattern but the apostrophe is safely in double quotes.
            if echo "$LINETEXT" | grep -qP '"[^"]*'"'"'[^"]*"' 2>/dev/null; then continue; fi
            # Skip raw strings.
            if echo "$LINETEXT" | grep -qP "r'" 2>/dev/null; then continue; fi
            echo "  WARN   $REL_PATH:$LINENUM: possible unescaped apostrophe in single-quoted string"
            TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
        done <<< "$MATCHES"
    fi
done

echo ""
echo "Results: $TOTAL_ERRORS error(s), $TOTAL_WARNINGS warning(s)"

if [ "$TOTAL_ERRORS" -gt 0 ]; then
    echo ""
    echo "Fix errors before committing. Tips:"
    echo "  - Use double quotes for strings with apostrophes: \"St. John's\""
    echo "  - Or escape properly: 'St. John\\'s'"
    echo "  - For code-gen pipelines, use SafeString.toDartLiteral()"
    exit 1
fi

if [ "$TOTAL_WARNINGS" -gt 0 ]; then
    echo ""
    echo "Warnings found — review manually to confirm they are safe."
fi

exit 0
