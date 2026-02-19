#!/bin/bash
# Build Flit for all platforms

set -e

PLATFORM=${1:-all}

build_web() {
    echo "🌐 Building web..."
    flutter build web --release --dart2js-optimization=O3 --base-href "/flit/"
    echo "✅ Web build complete: build/web/"
}

build_android() {
    echo "🤖 Building Android..."
    flutter build apk --release
    echo "✅ Android build complete: build/app/outputs/flutter-apk/"
}

build_ios() {
    echo "🍎 Building iOS..."
    flutter build ios --release --no-codesign
    echo "✅ iOS build complete: build/ios/"
}

case $PLATFORM in
    web)
        build_web
        ;;
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    all)
        build_web
        build_android
        # iOS only on macOS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            build_ios
        else
            echo "⚠️ Skipping iOS build (not on macOS)"
        fi
        ;;
    *)
        echo "Usage: $0 [web|android|ios|all]"
        exit 1
        ;;
esac

echo ""
echo "🎉 Build complete!"
