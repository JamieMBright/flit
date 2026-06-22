#!/bin/bash
# Run Flit end-to-end integration tests.
#
# Usage:
#   ./scripts/test-e2e.sh              # host runner (no device required)
#   ./scripts/test-e2e.sh --device <id> # real device / emulator

set -e

DEVICE_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device|-d)
      DEVICE_ID="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: ./scripts/test-e2e.sh [--device <device-id>]"
      exit 1
      ;;
  esac
done

echo "Running Flit E2E integration tests..."
echo ""

if [[ -n "$DEVICE_ID" ]]; then
  echo "Mode: real device ($DEVICE_ID) — running integration_test/"
  flutter test --device-id="$DEVICE_ID" integration_test/
else
  echo "Mode: host runner (no device) — running test/integration/"
  flutter test test/integration/
fi

echo ""
echo "E2E integration tests passed!"
