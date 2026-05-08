#!/usr/bin/env bash
set -euo pipefail

RPC_URL="${GORKH_DEVNET_RPC:-https://api.devnet.solana.com}"

echo "GORKH devnet smoke preflight"
echo "RPC: ${RPC_URL}"
echo

if command -v curl >/dev/null 2>&1; then
  echo "Checking devnet RPC health..."
  curl -sS "${RPC_URL}" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
  echo
  echo
else
  echo "curl is not installed; skipping RPC health check."
fi

cat <<'CHECKLIST'

Manual app checklist:
1. Run the GORKH macOS app.
2. Select Devnet.
3. Create or import a local test wallet.
4. Fund it with devnet SOL.
5. Refresh balance and record the starting balance.
6. Draft a 0.001 SOL send to a devnet recipient.
7. Simulate and verify success.
8. Approve in the native UI.
9. Confirm the transaction signature on Solana Explorer with cluster=devnet.
10. Refresh balances and verify sender/recipient changes.
11. Confirm audit events contain no secret material.

Do not run mainnet until this manual checklist passes.
CHECKLIST
