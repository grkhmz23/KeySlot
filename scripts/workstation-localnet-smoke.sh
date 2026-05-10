#!/usr/bin/env bash
set -euo pipefail

MODE="check"
KEEP_VALIDATOR="false"
SKIP_START_VALIDATOR="false"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLE="$ROOT/samples/anchor-hello-world"

usage() {
  cat <<'USAGE'
Developer Workstation localnet smoke

Usage:
  scripts/workstation-localnet-smoke.sh [mode] [options]

Modes:
  --check              Validate fixtures and tool availability, then exit safely.
  --start-validator    Start local validator only, if one is not already running.
  --build-sample       Build the sample Anchor project when Anchor is available.
  --deploy-sample      Build/deploy the sample to an existing local validator.
  --full-localnet      Start validator if needed, build sample, deploy, verify, clean up.

Options:
  --skip-start-validator  Require an existing local validator for deploy/full modes.
  --keep-validator        Leave a validator running if this script started it.
  --help                  Show this message.

No mainnet, no devnet by default, no arbitrary project path, and no unverified installer execution.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --start-validator)
      MODE="start-validator"
      shift
      ;;
    --build-sample)
      MODE="build-sample"
      shift
      ;;
    --deploy-sample)
      MODE="deploy-sample"
      shift
      ;;
    --full-localnet|--live)
      MODE="full-localnet"
      shift
      ;;
    --skip-start-validator)
      SKIP_START_VALIDATOR="true"
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

have_tool() {
  command -v "$1" >/dev/null 2>&1
}

tool_status() {
  if have_tool "$1"; then
    echo "$1: found"
    return 0
  fi
  echo "$1: missing"
  return 1
}

SOLANA_OK=0
VALIDATOR_OK=0
ANCHOR_OK=0
tool_status solana || SOLANA_OK=1
tool_status solana-test-validator || VALIDATOR_OK=1
tool_status anchor || ANCHOR_OK=1

if [[ "$MODE" == "check" ]]; then
  echo "check mode complete; live localnet build/deploy skipped"
  exit 0
fi

if [[ "$SOLANA_OK" -ne 0 ]]; then
  echo "localnet smoke skipped because Solana CLI is missing"
  exit 0
fi

if [[ "$MODE" == "build-sample" || "$MODE" == "deploy-sample" || "$MODE" == "full-localnet" ]]; then
  if [[ "$ANCHOR_OK" -ne 0 ]]; then
    echo "localnet smoke skipped because Anchor CLI is missing"
    exit 0
  fi
fi

if [[ "$MODE" == "start-validator" || "$MODE" == "deploy-sample" || "$MODE" == "full-localnet" ]]; then
  if [[ "$VALIDATOR_OK" -ne 0 ]]; then
    echo "localnet smoke skipped because solana-test-validator is missing"
    exit 0
  fi
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

validator_running() {
  solana --url http://127.0.0.1:8899 cluster-version >/dev/null 2>&1
}

start_validator_if_needed() {
  if validator_running; then
    echo "local validator: already running externally or from another process"
    return 0
  fi
  if [[ "$SKIP_START_VALIDATOR" == "true" ]]; then
    echo "local validator: required but not running"
    return 1
  fi
  echo "local validator: starting with fixed args"
  solana-test-validator --ledger "$LEDGER" --rpc-port 8899 --faucet-port 9900 --limit-ledger-size 50000000 >"$VALIDATOR_LOG" 2>&1 &
  VALIDATOR_PID="$!"
  STARTED_VALIDATOR="true"
  for _ in {1..40}; do
    if validator_running; then
      echo "local validator: ready"
      return 0
    fi
    sleep 1
  done
  echo "local validator: startup timed out"
  return 1
}

build_sample() {
  echo "anchor build: starting"
  (cd "$SAMPLE" && anchor build)
}

deploy_sample() {
  solana-keygen new --silent --no-bip39-passphrase --force -o "$KEYPAIR" >/dev/null
  chmod 0600 "$KEYPAIR"
  solana --url http://127.0.0.1:8899 airdrop 2 "$(solana-keygen pubkey "$KEYPAIR")" >/dev/null

  local artifact="$SAMPLE/target/deploy/hello_world.so"
  if [[ ! -f "$artifact" ]]; then
    echo "program artifact missing after build"
    return 1
  fi

  echo "solana program deploy: starting"
  local deploy_output
  deploy_output="$(solana program deploy "$artifact" --url http://127.0.0.1:8899 --keypair "$KEYPAIR")"
  echo "$deploy_output"
  local program_id
  program_id="$(printf '%s\n' "$deploy_output" | awk '/Program Id:/ {print $3}' | tail -n 1)"
  if [[ -z "$program_id" ]]; then
    echo "program id unavailable from deploy output"
    return 1
  fi
  solana program show "$program_id" --url http://127.0.0.1:8899 >/dev/null
  echo "program show: verified $program_id"
}

case "$MODE" in
  start-validator)
    start_validator_if_needed
    ;;
  build-sample)
    build_sample
    ;;
  deploy-sample)
    start_validator_if_needed
    build_sample
    deploy_sample
    ;;
  full-localnet)
    start_validator_if_needed
    build_sample
    deploy_sample
    ;;
  *)
    echo "unsupported mode: $MODE"
    exit 2
    ;;
esac

echo "localnet smoke complete"
