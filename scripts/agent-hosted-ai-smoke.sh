#!/usr/bin/env bash
set -euo pipefail

MODE="auto"
SCENARIO="all"
BASE_URL="${GORKH_AGENT_API_BASE_URL:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mock)
      MODE="mock"
      shift
      ;;
    --scenario)
      SCENARIO="${2:-all}"
      shift 2
      ;;
    --url)
      BASE_URL="${2:-}"
      MODE="remote"
      shift 2
      ;;
    --help)
      cat <<'HELP'
Usage: scripts/agent-hosted-ai-smoke.sh [--mock] [--scenario portfolio|clarify|pusd|unsafe|malformed|all] [--url https://agent.example]

Validates the hosted Agent API schema with safe fixture context only.
No wallet secrets, API keys, transaction payloads, signing material, or private vault data are printed.
HELP
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for JSON schema validation" >&2
  exit 1
fi

if [[ "$MODE" == "auto" && -z "$BASE_URL" ]]; then
  MODE="mock"
fi

HOST_LABEL="mock"
if [[ -n "$BASE_URL" ]]; then
  HOST_LABEL="$(python3 - "$BASE_URL" <<'PY'
from urllib.parse import urlparse
import sys
print(urlparse(sys.argv[1]).hostname or "configured")
PY
)"
fi

echo "Agent hosted AI smoke"
echo "mode: $MODE"
echo "endpoint: $HOST_LABEL"
if [[ -n "${GORKH_AGENT_API_KEY:-}" ]]; then
  echo "auth: present-redacted"
else
  echo "auth: missing"
fi

fixture_request() {
  cat <<'JSON'
{
  "conversationId": "00000000-0000-0000-0000-000000000001",
  "messageId": "00000000-0000-0000-0000-000000000002",
  "userMessage": "summarize my portfolio",
  "redactedContext": {
    "wallet": {
      "selectedWallet": "1111...1111",
      "walletKind": "Watch-only",
      "canSign": false,
      "network": "Mainnet Beta",
      "rpcTokenStatus": "Missing"
    },
    "portfolio": {
      "totalValueUSD": 0,
      "walletCount": 1,
      "assetCount": 0,
      "unavailablePriceCount": 0,
      "status": "Empty"
    },
    "pusd": {
      "balance": "0",
      "estimatedUSD": null,
      "walletCount": 0,
      "priceSource": "Unavailable",
      "circulationStatus": "Idle"
    },
    "yield": {
      "status": "Unavailable",
      "heldOpportunityCount": 0,
      "apyAvailableCount": 0,
      "unavailableCount": 0,
      "topSource": null
    },
    "liquidity": {
      "status": "Unavailable",
      "positionCount": 0,
      "estimatedValueUSD": null,
      "partialAdapterCount": 0
    },
    "pnl": {
      "status": "Unavailable",
      "historyPointCount": 0,
      "assetRows": 0,
      "realizedStatus": "Unavailable",
      "copy": "Performance estimate; not tax-grade accounting."
    },
    "activity": {
      "recentEvents": []
    },
    "zerion": {
      "cliStatus": "Unchecked",
      "apiCredentialStatus": "Missing",
      "automationCredentialStatus": "Missing",
      "policyStatus": "Unchecked",
      "swapCommandShape": "Unchecked"
    },
    "safetyMetadata": [
      "context_minimized",
      "wallet_addresses_redacted",
      "no_wallet_secrets",
      "no_raw_payloads",
      "proposals_require_policy"
    ],
    "builtAt": "2026-05-10T00:00:00Z"
  },
  "deterministicIntent": {
    "intentType": "portfolioSummary",
    "confidence": 0.95,
    "amount": null,
    "asset": null,
    "chain": null,
    "recipient": null,
    "targetLane": null,
    "missingFields": [],
    "riskFlags": [],
    "summary": "Portfolio summary request"
  },
  "policyState": {
    "mainWalletExecution": "blocked_in_agent_handoff_only",
    "zerionExecution": "existing_a2_tiny_swap_review_only",
    "cloakExecution": "wallet_private_handoff_only",
    "watchOnlyExecution": "analysis_only",
    "requiredApproval": "destination_module_policy_and_user_approval",
    "safetyMode": "redacted_context_minimized"
  },
  "allowedTools": [
    "summarizePortfolio",
    "summarizeRisk",
    "summarizeYield",
    "summarizeLPs",
    "summarizePnL",
    "draftSwapProposal",
    "draftPUSDPayment",
    "draftCloakPayment",
    "draftZerionTinySwap"
  ],
  "safetyMode": "hosted_ai_advisory_policy_deterministic",
  "clientVersion": "2026-05-10.a5"
}
JSON
}

mock_response() {
  case "$1" in
    portfolio)
      cat <<'JSON'
{"assistantMessage":"Your portfolio fixture is empty, so there is no live exposure to summarize.","suggestedIntent":"portfolioSummary","missingFields":[],"proposalSuggestion":null,"toolSuggestions":["summarizePortfolio"],"safetyWarnings":[],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-portfolio"}
JSON
      ;;
    clarify)
      cat <<'JSON'
{"assistantMessage":"Which token mint should I use for the buy draft?","suggestedIntent":"tokenBuyRequest","missingFields":["token mint"],"proposalSuggestion":null,"toolSuggestions":[],"safetyWarnings":["Missing token identity"],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-clarify"}
JSON
      ;;
    pusd)
      cat <<'JSON'
{"assistantMessage":"I can prepare a PUSD payment draft for Wallet review.","suggestedIntent":"pusdPaymentRequest","missingFields":["recipient","amount"],"proposalSuggestion":{"actionType":"pusdPaymentDraft","title":"PUSD payment draft","explanation":"Review in Wallet before any send.","riskNotes":["Destination approval required"],"missingFields":["recipient","amount"]},"toolSuggestions":[{"name":"draftPUSDPayment","reason":"Payment request only","confidence":0.9}],"safetyWarnings":[],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-pusd"}
JSON
      ;;
    unsafe)
      cat <<'JSON'
{"assistantMessage":"Unsafe fixture response.","suggestedIntent":"tokenSwapRequest","missingFields":[],"proposalSuggestion":{"actionType":"mainWalletSwapDraft","title":"Unsafe approval claim","explanation":"This must be ignored.","riskNotes":[],"missingFields":[],"status":"approved","executionApproved":true},"toolSuggestions":["draftSwapProposal","executeSwap","sendTransaction","runShell"],"safetyWarnings":["This response intentionally contains blocked suggestions."],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-unsafe"}
JSON
      ;;
    malformed)
      cat <<'JSON'
{"assistantMessage":"Malformed fixture with minimal fields only."}
JSON
      ;;
    *)
      echo "Unknown mock scenario: $1" >&2
      exit 2
      ;;
  esac
}

validate_response() {
  local scenario="$1"
  local response_file
  response_file="$(mktemp)"
  cat > "$response_file"
  python3 - "$scenario" "$response_file" <<'PY'
import json
import sys

scenario = sys.argv[1]
payload = open(sys.argv[2], "r", encoding="utf-8").read()
try:
    data = json.loads(payload)
except Exception as exc:
    print(f"{scenario}: invalid json: {exc}", file=sys.stderr)
    sys.exit(1)

if "assistantMessage" not in data:
    print(f"{scenario}: missing assistantMessage", file=sys.stderr)
    sys.exit(1)

tool_suggestions = data.get("toolSuggestions", [])
names = []
for tool in tool_suggestions:
    if isinstance(tool, str):
        names.append(tool)
    elif isinstance(tool, dict):
        names.append(str(tool.get("name", "")))

blocked_names = {"executeSwap", "sendTransaction", "signTransaction", "bridge", "sendToken", "exportSeed", "revealPrivateKey", "runShell", "arbitraryCommand"}
blocked = [name for name in names if name in blocked_names or name not in {
    "summarizePortfolio", "summarizeRisk", "summarizeYield", "summarizeLPs", "summarizePnL",
    "draftSwapProposal", "draftPUSDPayment", "draftCloakPayment", "draftZerionTinySwap"
}]

proposal = data.get("proposalSuggestion") or {}
approval_claim = bool(proposal.get("executionApproved")) or str(proposal.get("status", "")).lower() in {"approved", "executed"}

if scenario == "unsafe":
    if not blocked or not approval_claim:
        print("unsafe: expected blocked tools and ignored approval claim", file=sys.stderr)
        sys.exit(1)
else:
    if blocked:
        print(f"{scenario}: unexpected unsafe tools: {blocked}", file=sys.stderr)
        sys.exit(1)

if "modelInfo" in data:
    contract = data.get("modelInfo", {}).get("contractVersion")
    if contract and contract != "2026-05-10.a5":
        print(f"{scenario}: unexpected contract version {contract}", file=sys.stderr)
        sys.exit(1)

print(f"{scenario}: pass requestId={data.get('requestId', 'none')} blockedTools={len(blocked)}")
PY
  rm -f "$response_file"
}

run_mock_scenario() {
  local scenario="$1"
  mock_response "$scenario" | validate_response "$scenario"
}

run_remote_scenario() {
  local request_file response_file curl_config
  request_file="$(mktemp)"
  response_file="$(mktemp)"
  curl_config="$(mktemp)"
  chmod 600 "$curl_config"
  trap 'rm -f "$request_file" "$response_file" "$curl_config"' RETURN
  fixture_request > "$request_file"

  if [[ -n "${GORKH_AGENT_API_KEY:-}" ]]; then
    printf 'header = "Authorization: Bearer %s"\n' "${GORKH_AGENT_API_KEY}" > "$curl_config"
    curl -fsS \
      --config "$curl_config" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --data-binary "@${request_file}" \
      "${BASE_URL%/}/v1/agent/chat" > "$response_file"
  else
    curl -fsS \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --data-binary "@${request_file}" \
      "${BASE_URL%/}/v1/agent/chat" > "$response_file"
  fi

  validate_response "remote" < "$response_file"
}

if [[ "$MODE" == "mock" ]]; then
  if [[ "$SCENARIO" == "all" ]]; then
    for scenario in portfolio clarify pusd unsafe malformed; do
      run_mock_scenario "$scenario"
    done
  else
    run_mock_scenario "$SCENARIO"
  fi
else
  if [[ -z "$BASE_URL" ]]; then
    echo "GORKH_AGENT_API_BASE_URL is missing; use --mock for fixture validation" >&2
    exit 1
  fi
  run_remote_scenario
fi

echo "Agent hosted AI smoke passed"
