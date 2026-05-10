#!/usr/bin/env bash
set -euo pipefail

MODE="check"
KEEP_VALIDATOR="false"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLE="$ROOT/samples/anchor-hello-world"

usage() {
  cat <<'USAGE'
Developer Workstation localnet smoke

Usage:
  scripts/workstation-localnet-smoke.sh [--check] [--live] [--keep-validator]

Default --check mode validates fixtures and tool availability, then exits safely.
--live starts local validator if needed, builds the sample Anchor project, deploys to localnet, and cleans temporary key material.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --live)
      MODE="live"
      shift
      ;;
    --keep-validator)
      KEEP_VALIDATOR="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

echo "Developer Workstation localnet smoke"
echo "mode: $MODE"

if [[ ! -f "$SAMPLE/Anchor.toml" ]]; then
  echo "sample project missing"
  exit 1
fi

missing=0
for tool in solana solana-test-validator anchor; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "$tool: found"
  else
    echo "$tool: missing"
    missing=1
  fi
done

if [[ "$MODE" != "live" ]]; then
  echo "check mode complete; live localnet build/deploy skipped"
  exit 0
fi

if [[ "$missing" -ne 0 ]]; then
  echo "live smoke skipped because required tools are missing"
  exit 0
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/gorkh-workstation-smoke.XXXXXX")"
KEYPAIR="$WORKDIR/developer-authority.json"
LEDGER="$WORKDIR/ledger"
VALIDATOR_LOG="$WORKDIR/validator.log"
STARTED_VALIDATOR="false"

cleanup() {
  if [[ "$STARTED_VALIDATOR" == "true" && "$KEEP_VALIDATOR" != "true" && -n "${VALIDATOR_PID:-}" ]]; then
    kill "$VALIDATOR_PID" >/dev/null 2>&1 || true
    wait "$VALIDATOR_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

if solana --url http://127.0.0.1:8899 cluster-version >/dev/null 2>&1; then
  echo "local validator: already running"
else
  echo "local validator: starting"
  solana-test-validator --ledger "$LEDGER" --rpc-port 8899 --faucet-port 9900 --limit-ledger-size 50000000 >"$VALIDATOR_LOG" 2>&1 &
  VALIDATOR_PID="$!"
  STARTED_VALIDATOR="true"
  for _ in {1..40}; do
    if solana --url http://127.0.0.1:8899 cluster-version >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

solana-keygen new --silent --no-bip39-passphrase --force -o "$KEYPAIR" >/dev/null
chmod 0600 "$KEYPAIR"
solana --url http://127.0.0.1:8899 airdrop 2 "$(solana-keygen pubkey "$KEYPAIR")" >/dev/null

echo "anchor build: starting"
(cd "$SAMPLE" && anchor build)

echo "anchor deploy: starting"
(cd "$SAMPLE" && anchor deploy --provider.cluster http://127.0.0.1:8899 --provider.wallet "$KEYPAIR")

echo "localnet smoke complete"
