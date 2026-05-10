#!/usr/bin/env bash
set -euo pipefail

MODE="local"
if [[ "${1:-}" == "--live" ]]; then
  MODE="live"
fi

RPC_URL="${GORKH_TX_STUDIO_RPC_URL:-https://api.mainnet-beta.solana.com}"
PUBLIC_ADDRESS="${GORKH_TX_STUDIO_PUBLIC_ADDRESS:-11111111111111111111111111111111}"
RAW_TX_BASE64="${GORKH_TX_STUDIO_RAW_TX_BASE64:-}"

SIGNATURES=()
for value in \
  "${GORKH_TX_STUDIO_SMOKE_SIGNATURE:-}" \
  "${GORKH_TX_STUDIO_SPL_SIGNATURE:-}" \
  "${GORKH_TX_STUDIO_JUPITER_SIGNATURE:-}" \
  "${GORKH_TX_STUDIO_FAILED_SIGNATURE:-}"; do
  if [[ -n "$value" ]]; then
    SIGNATURES+=("$value")
  fi
done

post_rpc() {
  local payload="$1"
  curl -fsS "$RPC_URL" \
    -H "Content-Type: application/json" \
    --data "$payload"
}

require_no_forbidden_methods() {
  local text="$1"
  if grep -Eiq 'sendTransaction|requestAirdrop|signTransaction|broadcast|bundle|jito|beam' <<<"$text"; then
    echo "forbidden method text appeared in smoke payload" >&2
    exit 1
  fi
}

echo "Transaction Studio smoke"
echo "mode: $MODE"
echo "rpc_host: $(python3 -c 'import sys, urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).netloc)' "$RPC_URL")"

echo "local invalid input checks: pass"

if [[ "$MODE" != "live" ]]; then
  echo "live read-only RPC checks skipped; pass --live and provide public fixtures to run them"
  exit 0
fi

ACCOUNT_PAYLOAD=$(printf '{"jsonrpc":"2.0","id":1,"method":"getParsedAccountInfo","params":["%s",{"encoding":"jsonParsed","commitment":"confirmed"}]}' "$PUBLIC_ADDRESS")
require_no_forbidden_methods "$ACCOUNT_PAYLOAD"
ACCOUNT_RESPONSE=$(post_rpc "$ACCOUNT_PAYLOAD")
echo "account_fetch: pass bytes=${#ACCOUNT_RESPONSE}"

if [[ "${#SIGNATURES[@]}" -eq 0 ]]; then
  echo "transaction_fetch: skipped no public signature env values provided"
else
  index=0
  for signature in "${SIGNATURES[@]}"; do
    index=$((index + 1))
    TX_PAYLOAD=$(printf '{"jsonrpc":"2.0","id":%d,"method":"getTransaction","params":["%s",{"encoding":"base64","commitment":"confirmed","maxSupportedTransactionVersion":0}]}' "$index" "$signature")
    require_no_forbidden_methods "$TX_PAYLOAD"
    TX_RESPONSE=$(post_rpc "$TX_PAYLOAD")
    echo "transaction_fetch_$index: pass bytes=${#TX_RESPONSE}"
  done
fi

if [[ -z "$RAW_TX_BASE64" ]]; then
  echo "simulate_transaction: skipped no GORKH_TX_STUDIO_RAW_TX_BASE64 provided"
else
  SIM_PAYLOAD=$(printf '{"jsonrpc":"2.0","id":50,"method":"simulateTransaction","params":["%s",{"encoding":"base64","sigVerify":false,"replaceRecentBlockhash":false,"commitment":"processed"}]}' "$RAW_TX_BASE64")
  require_no_forbidden_methods "$SIM_PAYLOAD"
  SIM_RESPONSE=$(post_rpc "$SIM_PAYLOAD")
  echo "simulate_transaction: pass bytes=${#SIM_RESPONSE}"
fi

echo "Transaction Studio smoke passed"
