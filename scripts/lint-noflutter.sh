#!/bin/bash
# Lightweight Dart lint checks that run WITHOUT Flutter/Dart SDK.
# Catches common issues via pattern matching on staged (or all) Dart files.
#
# Usage:
#   ./scripts/lint-noflutter.sh            # Check all lib/ Dart files
#   ./scripts/lint-noflutter.sh --staged   # Check only staged files
#   ./scripts/lint-noflutter.sh [file...]  # Check specific files

set -euo pipefail

ERRORS=0
WARNINGS=0

# Determine which files to check
FILES=()
if [ "${1:-}" = "--staged" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && FILES+=("$f")
    done < <(git diff --cached --name-only --diff-filter=ACM -- '*.dart' 2>/dev/null || true)
elif [ $# -gt 0 ]; then
    FILES=("$@")
else
    while IFS= read -r f; do
        FILES+=("$f")
    done < <(find lib/ test/ -name '*.dart' -type f 2>/dev/null || true)
fi

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No Dart files to check."
    exit 0
fi

echo "Checking ${#FILES[@]} Dart file(s)..."
echo ""

# -----------------------------------------------------------------------
# Check 1: Unused private fields
# Looks for private field declarations (_name) that appear only once in
# the file (declaration only, never referenced).
# -----------------------------------------------------------------------
check_unused_privates() {
    local file="$1"
    # Find private field/method declarations (excluding _() constructors)
    while IFS= read -r match; do
        [ -z "$match" ] && continue
        local line_num=$(echo "$match" | cut -d: -f1)
        local line_text=$(echo "$match" | cut -d: -f2-)

        # Extract the private identifier
        local ident=$(echo "$line_text" | grep -oP '(?<!\w)_[a-zA-Z][a-zA-Z0-9_]*' | head -1)
        [ -z "$ident" ] && continue

        # Skip common patterns that aren't real unused fields
        case "$ident" in
            _build*|_init*|_dispose*|_create*|_on*) continue ;; # lifecycle methods
        esac

        # Count occurrences in the file (must appear more than once: declaration + usage)
        local count=$(grep -c "$ident" "$file" 2>/dev/null || echo 0)
        if [ "$count" -le 1 ]; then
            echo "  WARNING [$file:$line_num]: Private '$ident' appears only once (possibly unused)"
            WARNINGS=$((WARNINGS + 1))
        fi
    done < <(grep -nP '^\s+(final\s+|static\s+|late\s+)*([\w<>,\s]+)\s+_[a-zA-Z]' "$file" 2>/dev/null || true)
}

# -----------------------------------------------------------------------
# Check 2: Unused imports
# An import brings in a name; if that name never appears in the rest of
# the file, the import is likely unused.
# -----------------------------------------------------------------------
check_unused_imports() {
    local file="$1"
    while IFS= read -r match; do
        [ -z "$match" ] && continue
        local line_num=$(echo "$match" | cut -d: -f1)
        local line_text=$(echo "$match" | cut -d: -f2-)

        # Check for 'as X' alias
        local alias=$(echo "$line_text" | grep -oP '(?<=as )\w+' || true)
        if [ -n "$alias" ]; then
            # Check if alias is used elsewhere in file
            local usage=$(grep -c "$alias\." "$file" 2>/dev/null || echo 0)
            if [ "$usage" -le 0 ]; then
                echo "  WARNING [$file:$line_num]: Import alias '$alias' may be unused"
                WARNINGS=$((WARNINGS + 1))
            fi
            continue
        fi

        # Check for 'show X, Y' imports
        local shown=$(echo "$line_text" | grep -oP '(?<=show )\w+' || true)
        if [ -n "$shown" ]; then
            # Each shown name should appear in the file
            for name in $shown; do
                local usage=$(grep -c "\b$name\b" "$file" 2>/dev/null || echo 0)
                if [ "$usage" -le 1 ]; then
                    echo "  WARNING [$file:$line_num]: Imported name '$name' may be unused"
                    WARNINGS=$((WARNINGS + 1))
                fi
            done
            continue
        fi

        # For plain imports, extract the last segment of the path as the likely class name
        local path=$(echo "$line_text" | grep -oP "(?<=')[^']+(?=')" || true)
        [ -z "$path" ] && continue
        local basename=$(echo "$path" | sed 's|.*/||; s|\.dart$||')
        [ -z "$basename" ] && continue

        # Convert snake_case to likely PascalCase usage
        local pascal=$(echo "$basename" | sed -r 's/(^|_)([a-z])/\U\2/g')

        # Also check for direct filename reference (e.g. functions from the import)
        local usage_pascal=$(grep -c "\b$pascal\b" "$file" 2>/dev/null || echo 0)
        local usage_snake=$(grep -c "\b$basename\b" "$file" 2>/dev/null || echo 0)

        # Subtract the import line itself
        usage_snake=$((usage_snake - 1))

        if [ "$usage_pascal" -le 0 ] && [ "$usage_snake" -le 0 ]; then
            # Only warn, not error - the heuristic can have false positives
            echo "  INFO [$file:$line_num]: Import '$basename' ($pascal) may be unused"
        fi
    done < <(grep -nP "^import\s+'[^']+'" "$file" 2>/dev/null || true)
}

# -----------------------------------------------------------------------
# Check 3: Common const constructor candidates
# Catches simple cases where a constructor with all-literal args should
# be const (e.g., EdgeInsets.all(8), Offset(0, 0), Color(0xFF...)).
# -----------------------------------------------------------------------
check_const_constructors() {
    local file="$1"

    # Pattern: non-const EdgeInsets/Offset/Color/Duration/Radius with literal args
    while IFS= read -r match; do
        [ -z "$match" ] && continue
        local line_num=$(echo "$match" | cut -d: -f1)
        local line_text=$(echo "$match" | cut -d: -f2-)

        # Skip if already in a const context:
        # - Line starts with const
        # - 'const' appears anywhere on the same line (covers nested const constructors)
        # - 'const [' or 'const {' on the same line (list/map literals)
        # This is deliberately permissive to avoid false positives — the real
        # analyzer handles the nuances of Dart const propagation.
        if echo "$line_text" | grep -qP '\bconst\b' 2>/dev/null; then continue; fi

        echo "  INFO [$file:$line_num]: Consider adding 'const' to constructor (prefer_const_constructors)"
    done < <(grep -nP '(?<!\bconst\s)(?<!\bconst\s\s)\b(EdgeInsets\.(all|only|symmetric|fromLTRB)|Offset|Color|Duration|Radius\.(circular|elliptical)|SizedBox)\s*\([0-9., xeE+\-]*\)' "$file" 2>/dev/null || true)
}

# -----------------------------------------------------------------------
# Check 4: Print statements (should use logging instead)
# -----------------------------------------------------------------------
check_print_statements() {
    local file="$1"
    # Skip test files
    if echo "$file" | grep -q 'test/' 2>/dev/null; then return; fi

    while IFS= read -r match; do
        [ -z "$match" ] && continue
        local line_num=$(echo "$match" | cut -d: -f1)
        local line_text=$(echo "$match" | cut -d: -f2-)

        # Skip comments
        if echo "$line_text" | grep -qP '^\s*//' 2>/dev/null; then continue; fi

        echo "  WARNING [$file:$line_num]: print() statement found (use debugPrint or logging)"
        WARNINGS=$((WARNINGS + 1))
    done < <(grep -nP '(?<!\w)print\s*\(' "$file" 2>/dev/null || true)
}

# -----------------------------------------------------------------------
# Check 5: Bracket/paren/brace balance
# Quick check that each file has balanced delimiters.
# -----------------------------------------------------------------------
check_bracket_balance() {
    local file="$1"

    # Strip comments to reduce noise. We cannot perfectly strip Dart string
    # literals from bash (raw strings r'...', interpolation, multi-line strings
    # all defeat simple regex). So we use a tolerance threshold: small
    # imbalances (<=3) are likely brackets inside string literals and are
    # reported as warnings. Large imbalances (>3) indicate real syntax errors
    # and are reported as errors. The real analyzer (flutter analyze) is the
    # authoritative check — this is just a fast pre-commit heuristic.
    local content=$(sed -e 's|//.*||' -e 's|/\*.*\*/||g' "$file" 2>/dev/null || cat "$file")

    local opens closes diff

    opens=$(echo "$content" | tr -cd '(' | wc -c)
    closes=$(echo "$content" | tr -cd ')' | wc -c)
    diff=$(( opens - closes ))
    diff=${diff#-}  # absolute value
    if [ "$diff" -gt 3 ]; then
        echo "  ERROR [$file]: Unbalanced parentheses (opened: $opens, closed: $closes)"
        ERRORS=$((ERRORS + 1))
    elif [ "$diff" -gt 0 ]; then
        echo "  INFO [$file]: Minor paren imbalance (opened: $opens, closed: $closes) — likely string content"
    fi

    opens=$(echo "$content" | tr -cd '{' | wc -c)
    closes=$(echo "$content" | tr -cd '}' | wc -c)
    diff=$(( opens - closes ))
    diff=${diff#-}
    if [ "$diff" -gt 3 ]; then
        echo "  ERROR [$file]: Unbalanced braces (opened: $opens, closed: $closes)"
        ERRORS=$((ERRORS + 1))
    elif [ "$diff" -gt 0 ]; then
        echo "  INFO [$file]: Minor brace imbalance (opened: $opens, closed: $closes) — likely string content"
    fi

    opens=$(echo "$content" | tr -cd '[' | wc -c)
    closes=$(echo "$content" | tr -cd ']' | wc -c)
    diff=$(( opens - closes ))
    diff=${diff#-}
    if [ "$diff" -gt 3 ]; then
        echo "  ERROR [$file]: Unbalanced brackets (opened: $opens, closed: $closes)"
        ERRORS=$((ERRORS + 1))
    elif [ "$diff" -gt 0 ]; then
        echo "  INFO [$file]: Minor bracket imbalance (opened: $opens, closed: $closes) — likely string content"
    fi
}

# -----------------------------------------------------------------------
# Run all checks on each file
# -----------------------------------------------------------------------
for file in "${FILES[@]}"; do
    check_unused_privates "$file"
    check_const_constructors "$file"
    check_print_statements "$file"
    check_bracket_balance "$file"
done

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo "PASSED with $WARNINGS warning(s) - review before committing"
    exit 0
else
    echo "All checks passed."
    exit 0
fi
