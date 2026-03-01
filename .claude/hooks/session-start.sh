#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

DART_SDK_DIR="/tmp/dart-sdk"
DART_BIN="$DART_SDK_DIR/bin/dart"

# Install Dart SDK if not already present (cached across sessions)
if [ ! -x "$DART_BIN" ]; then
  echo "Installing Dart SDK..."
  curl -fsSL https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -o /tmp/dart.zip
  unzip -qo /tmp/dart.zip -d /tmp/
  rm -f /tmp/dart.zip
  echo "Dart SDK installed: $("$DART_BIN" --version 2>&1)"
else
  echo "Dart SDK already installed: $("$DART_BIN" --version 2>&1)"
fi

# Persist Dart SDK on PATH for the session
echo "export PATH=\"$DART_SDK_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Install git hooks if .git directory exists
if [ -d "$CLAUDE_PROJECT_DIR/.git" ] && [ -f "$CLAUDE_PROJECT_DIR/scripts/setup-hooks.sh" ]; then
  echo "Setting up git hooks..."
  bash "$CLAUDE_PROJECT_DIR/scripts/setup-hooks.sh" || true
fi

echo "Session setup complete."
