#!/usr/bin/env bash
set -euo pipefail

NETWORK="mainnet"
EXPECTED=""
WALLET="${GORKH_RAYDIUM_SMOKE_WALLET:-11111111111111111111111111111111}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wallet)
      WALLET="${2:-}"
      shift 2
      ;;
    --mainnet)
      NETWORK="mainnet"
      shift
      ;;
    --devnet)
      NETWORK="devnet"
      shift
      ;;
    --expected|--expect)
      EXPECTED="${2:-}"
      shift 2
      ;;
    *)
      echo "Unsupported argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ "$NETWORK" == "devnet" ]]; then
  OWNER_HOST="https://owner-v1-devnet.raydium.io"
else
  OWNER_HOST="https://owner-v1.raydium.io"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

safe_count() {
  local file="$1"
  node -e '
const fs = require("fs");
const file = process.argv[1];
const text = fs.readFileSync(file, "utf8").trim();
if (!text) { console.log(0); process.exit(0); }
const root = JSON.parse(text);
function extract(value) {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== "object") return [];
  for (const key of ["data", "rows", "list", "items", "positions"]) {
    const candidate = value[key];
    if (Array.isArray(candidate)) return candidate;
    const nested = extract(candidate);
    if (nested.length) return nested;
  }
  return [];
}
console.log(extract(root).length);
' "$file"
}

fetch_endpoint() {
  local path="$1"
  local output="$2"
  local url="$OWNER_HOST$path"
  curl -sS -o "$output" -w "%{http_code}" "$url" || true
}

STAKE_FILE="$TMP_DIR/stake.json"
CLMM_FILE="$TMP_DIR/clmm.json"
STAKE_CODE="$(fetch_endpoint "/position/stake/$WALLET" "$STAKE_FILE")"
CLMM_CODE="$(fetch_endpoint "/position/clmm-lock/$WALLET" "$CLMM_FILE")"

STAKE_COUNT=0
CLMM_COUNT=0
STATUS="empty"
REASON=""

if [[ "$STAKE_CODE" == "200" ]]; then
  STAKE_COUNT="$(safe_count "$STAKE_FILE" || echo 0)"
elif [[ "$STAKE_CODE" == "404" ]]; then
  STAKE_COUNT=0
else
  STATUS="unavailable"
  REASON="stake endpoint HTTP $STAKE_CODE"
fi

if [[ "$CLMM_CODE" == "200" ]]; then
  CLMM_COUNT="$(safe_count "$CLMM_FILE" || echo 0)"
elif [[ "$CLMM_CODE" == "404" ]]; then
  CLMM_COUNT=0
else
  if [[ "$STATUS" == "empty" ]]; then
    STATUS="unavailable"
    REASON="clmm-lock endpoint HTTP $CLMM_CODE"
  else
    REASON="$REASON; clmm-lock endpoint HTTP $CLMM_CODE"
  fi
fi

TOTAL_COUNT=$((STAKE_COUNT + CLMM_COUNT))
if [[ "$STATUS" != "unavailable" && "$TOTAL_COUNT" -gt 0 ]]; then
  STATUS="loaded"
fi

MATCHED="true"
if [[ -n "$EXPECTED" && "$EXPECTED" != "$STATUS" ]]; then
  MATCHED="false"
fi

STATUS="$STATUS" \
EXPECTED="$EXPECTED" \
MATCHED="$MATCHED" \
WALLET="$WALLET" \
NETWORK="$NETWORK" \
OWNER_HOST="$OWNER_HOST" \
STAKE_CODE="$STAKE_CODE" \
CLMM_CODE="$CLMM_CODE" \
STAKE_COUNT="$STAKE_COUNT" \
CLMM_COUNT="$CLMM_COUNT" \
TOTAL_COUNT="$TOTAL_COUNT" \
REASON="$REASON" \
node -e '
const summary = {
  status: process.env.STATUS,
  expectedStatus: process.env.EXPECTED || null,
  expectedStatusMatched: process.env.MATCHED === "true",
  walletPublicAddress: process.env.WALLET,
  network: process.env.NETWORK,
  ownerHost: process.env.OWNER_HOST.replace(/^https:\/\//, ""),
  stakeStatusCode: process.env.STAKE_CODE,
  clmmLockStatusCode: process.env.CLMM_CODE,
  stakePositionCount: Number(process.env.STAKE_COUNT),
  clmmLockedPositionCount: Number(process.env.CLMM_COUNT),
  totalPositionCount: Number(process.env.TOTAL_COUNT),
  reason: process.env.REASON || null,
  timestamp: new Date().toISOString()
};
console.log(JSON.stringify(summary, null, 2));
'

if [[ "$MATCHED" != "true" ]]; then
  exit 1
fi
