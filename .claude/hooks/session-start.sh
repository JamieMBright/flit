#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="/tmp/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"
DART_BIN="$FLUTTER_DIR/bin/dart"

# Install Flutter SDK if not already present (cached across sessions)
if [ ! -x "$FLUTTER_BIN" ]; then
  echo "Installing Flutter SDK..."

  # Download Flutter SDK (stable channel, linux x64)
  curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.3-stable.tar.xz -o /tmp/flutter.tar.xz

  # Extract to /tmp (tar.xz extracts a 'flutter' directory)
  tar -xf /tmp/flutter.tar.xz -C /tmp/
  rm -f /tmp/flutter.tar.xz

  # Disable analytics and first-run experience
  "$FLUTTER_BIN" config --no-analytics 2>/dev/null || true
  "$DART_BIN" --disable-analytics 2>/dev/null || true

  # Pre-cache web artifacts (primary CI target)
  "$FLUTTER_BIN" precache --web 2>/dev/null || true

  echo "Flutter SDK installed: $("$FLUTTER_BIN" --version 2>&1 | head -1)"
  echo "Dart SDK included: $("$DART_BIN" --version 2>&1)"
else
  echo "Flutter SDK already installed: $("$FLUTTER_BIN" --version 2>&1 | head -1)"
  echo "Dart SDK included: $("$DART_BIN" --version 2>&1)"
fi

# Persist Flutter (and its bundled Dart) on PATH for the session
echo "export PATH=\"$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Run flutter pub get if pubspec.yaml exists
if [ -f "$CLAUDE_PROJECT_DIR/pubspec.yaml" ]; then
  echo "Running flutter pub get..."
  cd "$CLAUDE_PROJECT_DIR"
  "$FLUTTER_BIN" pub get 2>/dev/null || echo "Warning: flutter pub get failed (may need network)"
fi

# Install git hooks if .git directory exists
if [ -d "$CLAUDE_PROJECT_DIR/.git" ] && [ -f "$CLAUDE_PROJECT_DIR/scripts/setup-hooks.sh" ]; then
  echo "Setting up git hooks..."
  bash "$CLAUDE_PROJECT_DIR/scripts/setup-hooks.sh" || true
fi

echo "Session setup complete."
