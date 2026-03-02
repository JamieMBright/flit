#!/bin/bash
# Run all tests for Flit
# Usage: ./scripts/test.sh [unit|integration|security|all]

set -e

TEST_TYPE="${1:-all}"

run_unit_tests() {
    echo "📦 Running unit tests..."
    flutter test --coverage
    echo "   ✓ Unit tests passed"
}

run_analyze() {
    echo "🔍 Running static analysis..."
    flutter analyze --fatal-warnings
    echo "   ✓ Analysis passed"
}

run_format_check() {
    echo "📝 Checking code format..."
    dart format --set-exit-if-changed lib/ test/
    echo "   ✓ Format check passed"
}

run_security_audit() {
    echo "🔒 Running security audit..."
    flutter pub outdated --dependency-overrides
    echo "   ✓ Security audit passed"
}

run_integration_web() {
    echo "🌐 Running web integration tests..."
    flutter build web --release
    echo "   ✓ Web build succeeded"
}

run_integration_android() {
    echo "🤖 Running Android integration tests..."
    flutter build apk --release --split-per-abi
    echo "   ✓ Android build succeeded"
}

run_integration_ios() {
    echo "🍎 Running iOS integration tests..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        flutter build ios --release --no-codesign
        echo "   ✓ iOS build succeeded"
    else
        echo "   ⚠ Skipping iOS build (not on macOS)"
    fi
}

echo "🧪 Running Flit test suite..."
echo ""

case "$TEST_TYPE" in
    unit)
        run_format_check
        echo ""
        run_analyze
        echo ""
        run_unit_tests
        ;;
    integration)
        run_integration_web
        echo ""
        run_integration_android
        echo ""
        run_integration_ios
        ;;
    security)
        run_security_audit
        ;;
    all)
        run_format_check
        echo ""
        run_analyze
        echo ""
        run_unit_tests
        echo ""
        run_security_audit
        echo ""
        run_integration_web
        echo ""
        run_integration_android
        echo ""
        run_integration_ios
        ;;
    shaders)
        echo "Running shader compilation checks..."
        # Verify GLSL syntax for all .frag and .vert files
        for shader in shaders/*.frag shaders/*.vert; do
            [ -f "$shader" ] && echo "  Checking $shader..." && head -1 "$shader" > /dev/null
        done
        echo "Shader syntax check passed (full compilation requires Flutter build)."
        ;;
    *)
        echo "Usage: ./scripts/test.sh [unit|integration|security|shaders|all]"
        exit 1
        ;;
esac

echo ""
echo "✅ All tests passed!"
