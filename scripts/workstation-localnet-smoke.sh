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
  --check-avm          Check AVM and Anchor activation status, then exit safely.
  --update-avm         Try fixed AVM self-update, then fixed Cargo reinstall if needed.
  --activate-anchor-latest
                       Run fixed AVM install/use for Anchor latest, then verify.
  --activate-anchor-1-0-2
                       Run fixed AVM install/use for Anchor 1.0.2, then verify.
  --start-validator    Start local validator only, if one is not already running.
  --build-sample       Build the sample Anchor project when Anchor is available.
  --deploy-sample      Build/deploy the sample to an existing local validator.
  --full-localnet      Start validator if needed, build sample, deploy, verify, clean up.

Options:
  --skip-start-validator  Require an existing local validator for deploy/full modes.
  --keep-validator        Leave a validator running if this script started it.
  --help                  Show this message.

No mainnet, no devnet by default, no arbitrary project path, and no unverified installer execution.

Optional fixed Rust pin:
  GORKH_WORKSTATION_RUST_TOOLCHAIN=stable scripts/workstation-localnet-smoke.sh \
    --full-localnet
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --check)
      MODE="check"
      shift
      ;;
    --check-avm)
      MODE="check-avm"
      shift
      ;;
    --update-avm)
      MODE="update-avm"
      shift
      ;;
    --activate-anchor-latest)
      MODE="activate-anchor-latest"
      shift
      ;;
    --activate-anchor-1-0-2)
      MODE="activate-anchor-1-0-2"
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
    local version_output
    if version_output="$("$1" --version 2>&1)"; then
      echo "$1: found ($version_output)"
    else
      echo "$1: found"
    fi
    return 0
  fi
  echo "$1: missing"
  return 1
}

validate_rust_pin() {
  if [[ -z "${GORKH_WORKSTATION_RUST_TOOLCHAIN:-}" ]]; then
    return 0
  fi

  case "$GORKH_WORKSTATION_RUST_TOOLCHAIN" in
    stable|1.95.0)
      export RUSTUP_TOOLCHAIN="$GORKH_WORKSTATION_RUST_TOOLCHAIN"
      echo "rust pin: using fixed candidate $GORKH_WORKSTATION_RUST_TOOLCHAIN"
      ;;
    *)
      echo "localnet smoke skipped because GORKH_WORKSTATION_RUST_TOOLCHAIN is not a fixed candidate"
      exit 0
      ;;
  esac
}

anchor_status() {
  if ! have_tool anchor; then
    echo "anchor: missing"
    return 1
  fi

  local version_output
  if version_output="$(anchor --version 2>&1)"; then
    echo "anchor: ready ($version_output)"
    return 0
  fi

  echo "anchor: found but unusable ($(printf '%s' "$version_output" | head -n 1))"
  return 1
}

avm_status() {
  if ! have_tool avm; then
    echo "avm: missing"
    return 1
  fi

  local version_output
  if version_output="$(avm --version 2>&1)"; then
    echo "avm: ready ($version_output)"
    return 0
  fi

  echo "avm: found but version check failed ($(printf '%s' "$version_output" | head -n 1))"
  return 1
}

update_avm() {
  if have_tool avm; then
    echo "avm self-update: starting fixed command"
    if avm self-update; then
      avm --version
      return 0
    fi
    echo "avm self-update: unsupported or failed; trying fixed Cargo reinstall if Cargo is available"
  fi

  if ! have_tool cargo; then
    echo "avm update skipped because Cargo is missing"
    return 0
  fi

  cargo install --git https://github.com/solana-foundation/anchor avm --force
  avm --version
}

activate_anchor() {
  local version="$1"
  case "$version" in
    latest|1.0.2)
      ;;
    *)
      echo "anchor activation skipped because version is not a fixed candidate"
      exit 0
      ;;
  esac

  if ! have_tool avm; then
    echo "anchor activation skipped because AVM is missing"
    exit 0
  fi

  avm install "$version"
  avm use "$version"
  anchor --version
}

validate_rust_pin

tool_status rustc || true
tool_status cargo || true
avm_status || true

SOLANA_OK=0
VALIDATOR_OK=0
ANCHOR_OK=0
tool_status solana || SOLANA_OK=1
tool_status solana-test-validator || VALIDATOR_OK=1
anchor_status || ANCHOR_OK=1

if [[ "$MODE" == "check" ]]; then
  echo "check mode complete; live localnet build/deploy skipped"
  exit 0
fi

if [[ "$MODE" == "check-avm" ]]; then
  echo "check-avm mode complete; no install, build, or deploy was run"
  exit 0
fi

if [[ "$MODE" == "update-avm" ]]; then
  update_avm
  echo "update-avm mode complete; no Anchor install, build, or deploy was run"
  exit 0
fi

if [[ "$MODE" == "activate-anchor-latest" ]]; then
  activate_anchor "latest"
  echo "activate-anchor-latest mode complete; no build or deploy was run"
  exit 0
fi

if [[ "$MODE" == "activate-anchor-1-0-2" ]]; then
  activate_anchor "1.0.2"
  echo "activate-anchor-1-0-2 mode complete; no build or deploy was run"
  exit 0
fi

if [[ "$SOLANA_OK" -ne 0 ]]; then
  echo "localnet smoke skipped because Solana CLI is missing"
  exit 0
fi

if [[ "$MODE" == "build-sample" || "$MODE" == "deploy-sample" || "$MODE" == "full-localnet" ]]; then
  if [[ "$ANCHOR_OK" -ne 0 ]]; then
    echo "localnet smoke skipped because Anchor CLI is missing or unusable"
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
SMOKE_SAMPLE="$WORKDIR/anchor-hello-world"
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

prepare_sample_copy() {
  if [[ -d "$SMOKE_SAMPLE" ]]; then
    return 0
  fi

  cp -R "$SAMPLE" "$SMOKE_SAMPLE"
  mkdir -p "$SMOKE_SAMPLE/target/deploy"
  solana-keygen new --silent --force -o "$SMOKE_SAMPLE/target/deploy/hello_world-keypair.json" --no-bip39-passphrase >/dev/null
  chmod 0600 "$SMOKE_SAMPLE/target/deploy/hello_world-keypair.json"

  local sample_program_id
  sample_program_id="$(solana-keygen pubkey "$SMOKE_SAMPLE/target/deploy/hello_world-keypair.json")"
  sed -i.bak "s/declare_id!(\"[^\"]*\")/declare_id!(\"$sample_program_id\")/" "$SMOKE_SAMPLE/programs/hello-world/src/lib.rs"
  sed -i.bak "s/hello_world = \"[^\"]*\"/hello_world = \"$sample_program_id\"/" "$SMOKE_SAMPLE/Anchor.toml"
  if [[ -f "$SMOKE_SAMPLE/target/idl/hello_world.json" ]]; then
    sed -i.bak "s/\"address\": \"[^\"]*\"/\"address\": \"$sample_program_id\"/" "$SMOKE_SAMPLE/target/idl/hello_world.json"
  fi
  rm -f "$SMOKE_SAMPLE/programs/hello-world/src/lib.rs.bak" "$SMOKE_SAMPLE/Anchor.toml.bak" "$SMOKE_SAMPLE/target/idl/hello_world.json.bak"
  echo "sample project: prepared temporary localnet program id $sample_program_id"
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
  for _ in {1..90}; do
    if validator_running; then
      echo "local validator: ready"
      return 0
    fi
    sleep 1
  done
  echo "local validator: startup timed out"
  if [[ -f "$VALIDATOR_LOG" ]]; then
    echo "local validator log tail:"
    tail -n 40 "$VALIDATOR_LOG"
  fi
  return 1
}

build_sample() {
  prepare_sample_copy
  echo "anchor build: starting"
  (cd "$SMOKE_SAMPLE" && anchor build)
}

deploy_sample() {
  solana-keygen new --silent --force -o "$KEYPAIR" --no-bip39-passphrase >/dev/null
  chmod 0600 "$KEYPAIR"
  solana --url http://127.0.0.1:8899 airdrop 2 "$(solana-keygen pubkey "$KEYPAIR")" >/dev/null

  local artifact="$SMOKE_SAMPLE/target/deploy/hello_world.so"
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
