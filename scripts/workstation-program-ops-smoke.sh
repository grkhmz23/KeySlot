#!/usr/bin/env bash
set -euo pipefail

MODE="check"
CONFIRM_DEVNET="false"
CLUSTER="localnet"
PROGRAM_ID=""
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Developer Workstation program ops smoke

Usage:
  scripts/workstation-program-ops-smoke.sh [mode] [options]

Modes:
  --localnet-sample       Run the certified localnet sample smoke through the localnet script.
  --devnet-sample         Prepare controlled devnet sample certification; skips unless explicitly confirmed.
  --program-show          Print fixed program show preview for localnet/devnet.
  --upgrade-preview       Print fixed localnet/devnet upgrade preview only.
  --close-preview         Print fixed localnet/devnet close preview only.
  --authority-preview     Print fixed localnet/devnet authority transfer/revoke previews only.

Options:
  --confirm-devnet        Required for any devnet certification path.
  --cluster localnet|devnet
  --program-id <pubkey>   Public program id for preview/show modes.
  --help                  Show this message.

No mainnet, no arbitrary shell, no arbitrary flags, and no unverified installer execution.
Devnet deploy is not automatic. Set GORKH_WORKSTATION_DEVNET_DEPLOY=1 together with
--devnet-sample --confirm-devnet only for an intentional manual certification run.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --localnet-sample)
      MODE="localnet-sample"
      shift
      ;;
    --devnet-sample)
      MODE="devnet-sample"
      CLUSTER="devnet"
      shift
      ;;
    --program-show)
      MODE="program-show"
      shift
      ;;
    --upgrade-preview)
      MODE="upgrade-preview"
      shift
      ;;
    --close-preview)
      MODE="close-preview"
      shift
      ;;
    --authority-preview)
      MODE="authority-preview"
      shift
      ;;
    --confirm-devnet)
      CONFIRM_DEVNET="true"
      shift
      ;;
    --cluster)
      CLUSTER="${2:-}"
      shift 2
      ;;
    --program-id)
      PROGRAM_ID="${2:-}"
      shift 2
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

case "$CLUSTER" in
  localnet|devnet)
    ;;
  *)
    echo "program ops smoke skipped: cluster must be localnet or devnet"
    exit 0
    ;;
esac

echo "Developer Workstation program ops smoke"
echo "mode: $MODE"
echo "cluster: $CLUSTER"

rpc_url() {
  case "$CLUSTER" in
    localnet) echo "http://127.0.0.1:8899" ;;
    devnet) echo "https://api.devnet.solana.com" ;;
  esac
}

redacted_keypair="/tmp/[redacted-developer-authority].json"
artifact="target/deploy/hello_world.so"
program="${PROGRAM_ID:-11111111111111111111111111111111}"

case "$MODE" in
  check)
    echo "check mode complete; no program operation was run"
    ;;
  localnet-sample)
    exec "$ROOT/scripts/workstation-localnet-smoke.sh" --full-localnet
    ;;
  devnet-sample)
    if [[ "$CONFIRM_DEVNET" != "true" ]]; then
      echo "devnet sample skipped: pass --confirm-devnet for manual devnet certification"
      exit 0
    fi
    if [[ "${GORKH_WORKSTATION_DEVNET_DEPLOY:-0}" != "1" ]]; then
      echo "devnet sample skipped: set GORKH_WORKSTATION_DEVNET_DEPLOY=1 for intentional live devnet deploy"
      exit 0
    fi
    echo "devnet certification preflight passed; live deploy is intentionally not executed by this script revision"
    ;;
  program-show)
    echo "preview: solana program show $program --url $(rpc_url)"
    ;;
  upgrade-preview)
    echo "preview: solana program deploy $artifact --program-id $program --url $(rpc_url) --keypair $redacted_keypair"
    ;;
  close-preview)
    echo "preview: solana program close $program --url $(rpc_url) --keypair $redacted_keypair"
    ;;
  authority-preview)
    echo "preview: solana program set-upgrade-authority $program --new-upgrade-authority <new-public-key> --url $(rpc_url) --keypair $redacted_keypair"
    echo "preview: solana program set-upgrade-authority $program --final --url $(rpc_url) --keypair $redacted_keypair"
    ;;
esac
