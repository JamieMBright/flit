#!/bin/bash
# Run all tests for Flit

set -e

echo "🧪 Running Flit test suite..."

# Unit tests
echo ""
echo "📦 Running unit tests..."
flutter test --coverage

# Analyze
echo ""
echo "🔍 Running static analysis..."
flutter analyze --fatal-infos

echo ""
echo "✅ All tests passed!"
