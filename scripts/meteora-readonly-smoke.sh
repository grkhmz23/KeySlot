#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER_DIR="$ROOT_DIR/tools/meteora-readonly"

echo "GORKH Meteora read-only smoke"
echo "Helper: tools/meteora-readonly"
echo "Mode: public wallet and read-only RPC only"
echo

cd "$HELPER_DIR"
node src/smoke.ts "$@"
