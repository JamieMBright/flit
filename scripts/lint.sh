#!/bin/bash
# Lint and format Flit codebase

set -e

echo "🧹 Linting Flit..."

# Check formatting
echo ""
echo "📐 Checking formatting..."
dart format --set-exit-if-changed .

# Analyze
echo ""
echo "🔍 Running analysis..."
flutter analyze --fatal-infos

echo ""
echo "✅ Linting passed!"
