#!/bin/bash
# Lint and format Flit codebase
# Formatting and linting are advisory — they report issues but do not fail the build.

echo "Linting Flit..."

EXIT_CODE=0

# Check formatting (advisory)
echo ""
echo "Checking formatting..."
if ! dart format --set-exit-if-changed .; then
  echo "WARNING: Formatting issues found. Run 'dart format lib/ test/' to fix."
  EXIT_CODE=1
fi

# Analyze (advisory)
echo ""
echo "Running analysis..."
if ! flutter analyze --fatal-warnings; then
  echo "WARNING: Analysis issues found. Review output above."
  EXIT_CODE=1
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "Linting passed!"
else
  echo "Linting completed with warnings (non-blocking)."
fi

# Always exit 0 — formatting and lint issues are advisory, not blocking
exit 0
