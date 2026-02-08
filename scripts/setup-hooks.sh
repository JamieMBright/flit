#!/bin/bash
# Setup git hooks for local development
# Run this once after cloning the repo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_SRC="$PROJECT_ROOT/hooks"
HOOKS_DST="$PROJECT_ROOT/.git/hooks"

echo "🔧 Setting up git hooks..."

# Copy hooks
for hook in pre-commit pre-push; do
    if [ -f "$HOOKS_SRC/$hook" ]; then
        cp "$HOOKS_SRC/$hook" "$HOOKS_DST/$hook"
        chmod +x "$HOOKS_DST/$hook"
        echo "   ✓ Installed $hook hook"
    fi
done

echo ""
echo "Git hooks installed!"
echo ""
echo "Hooks will run automatically:"
echo "  pre-commit: string literal safety, format, analyze, unit tests"
echo "  pre-push: full build + all tests"
echo ""
echo "Standalone string safety scanner:"
echo "  ./scripts/check-strings.sh            # scan all lib/ Dart files"
echo "  ./scripts/check-strings.sh --staged   # scan staged files only"
echo ""
echo "To skip hooks (not recommended): git commit --no-verify"
