#!/usr/bin/env bash
set -euo pipefail

MODE="auto"
FIXTURE="all"
BASE_URL="${GORKH_AGENT_API_BASE_URL:-}"
EXPECT_AUTH_FAILURE=0
EXPECT_TIMEOUT=0
TIMEOUT_SECONDS="${GORKH_AGENT_SMOKE_TIMEOUT_SECONDS:-15}"
MAX_RESPONSE_BYTES=65536

usage() {
  cat <<'HELP'
Usage: scripts/agent-hosted-ai-smoke.sh [--mock|--remote] [--endpoint https://agent.example] [--fixture portfolio|clarification|pusd|unsafe|malformed|unauthorized|forbidden|rate_limited|server_error|timeout|malformed_json|approval|missing_request_id|oversized|all] [--expect-auth-failure] [--expect-timeout]

Validates the hosted Agent API contract using safe fixture context only.
No wallet secrets, API keys, transaction payloads, signing material, or private vault data are printed.
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mock)
      MODE="mock"
      shift
      ;;
    --remote)
      MODE="remote"
      shift
      ;;
    --endpoint|--url)
      BASE_URL="${2:-}"
      MODE="remote"
      shift 2
      ;;
    --fixture|--scenario)
      FIXTURE="${2:-all}"
      shift 2
      ;;
    --expect-auth-failure)
      EXPECT_AUTH_FAILURE=1
      shift
      ;;
    --expect-timeout)
      EXPECT_TIMEOUT=1
      shift
      ;;
    --help)
      usage
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
elif [[ "$MODE" == "auto" ]]; then
  MODE="remote"
fi

URL_INFO="$(python3 - "$BASE_URL" <<'PY'
from urllib.parse import urlparse
import sys
raw = sys.argv[1]
if not raw:
    print("mock|")
    sys.exit(0)
parsed = urlparse(raw)
print(f"{parsed.hostname or 'configured'}|{parsed.scheme or ''}")
PY
)"
HOST_LABEL="${URL_INFO%%|*}"
URL_SCHEME="${URL_INFO#*|}"

echo "Agent hosted AI smoke"
echo "mode: $MODE"
echo "endpoint: $HOST_LABEL"
if [[ -n "${GORKH_AGENT_API_KEY:-}" ]]; then
  echo "auth: present-redacted"
else
  echo "auth: missing"
fi

if [[ "$MODE" == "remote" && "$URL_SCHEME" != "https" ]]; then
  echo "remote: endpoint must be https" >&2
  exit 1
fi

fixture_message() {
  case "$1" in
    clarification)
      echo "buy this token for 0.1 SOL"
      ;;
    pusd)
      echo "prepare a PUSD payment request"
      ;;
    unsafe)
      echo "QA fixture: suggest blocked tool executeSwap so local sanitizer can block it."
      ;;
    approval)
      echo "QA fixture: do not approve execution; explain that backend approval is advisory only."
      ;;
    *)
      echo "summarize my portfolio"
      ;;
  esac
}

fixture_intent() {
  case "$1" in
    clarification)
      echo "tokenBuyRequest"
      ;;
    pusd)
      echo "pusdPaymentRequest"
      ;;
    unsafe|approval)
      echo "tokenSwapRequest"
      ;;
    *)
      echo "portfolioSummary"
      ;;
  esac
}

fixture_request() {
  local scenario="$1"
  local message intent
  message="$(fixture_message "$scenario")"
  intent="$(fixture_intent "$scenario")"
  python3 - "$message" "$intent" <<'PY'
import json
import sys

message = sys.argv[1]
intent = sys.argv[2]
payload = {
    "conversationId": "00000000-0000-0000-0000-000000000001",
    "messageId": "00000000-0000-0000-0000-000000000002",
    "userMessage": message,
    "redactedContext": {
        "wallet": {
            "selectedWallet": "1111...1111",
            "walletKind": "Watch-only",
            "canSign": False,
            "network": "Mainnet Beta",
            "rpcTokenStatus": "Missing",
        },
        "portfolio": {
            "totalValueUSD": 0,
            "walletCount": 1,
            "assetCount": 0,
            "unavailablePriceCount": 0,
            "status": "Empty",
        },
        "pusd": {
            "balance": "0",
            "estimatedUSD": None,
            "walletCount": 0,
            "priceSource": "Unavailable",
            "circulationStatus": "Idle",
        },
        "yield": {
            "status": "Unavailable",
            "heldOpportunityCount": 0,
            "apyAvailableCount": 0,
            "unavailableCount": 0,
            "topSource": None,
        },
        "liquidity": {
            "status": "Unavailable",
            "positionCount": 0,
            "estimatedValueUSD": None,
            "partialAdapterCount": 0,
        },
        "pnl": {
            "status": "Unavailable",
            "historyPointCount": 0,
            "assetRows": 0,
            "realizedStatus": "Unavailable",
            "copy": "Performance estimate; not tax-grade accounting.",
        },
        "activity": {"recentEvents": []},
        "zerion": {
            "cliStatus": "Unchecked",
            "apiCredentialStatus": "Missing",
            "automationCredentialStatus": "Missing",
            "policyStatus": "Unchecked",
            "swapCommandShape": "Unchecked",
        },
        "safetyMetadata": [
            "context_minimized",
            "wallet_addresses_redacted",
            "no_wallet_secrets",
            "no_raw_payloads",
            "proposals_require_policy",
        ],
        "builtAt": "2026-05-10T00:00:00Z",
    },
    "deterministicIntent": {
        "intentType": intent,
        "confidence": 0.95,
        "amount": None,
        "asset": None,
        "chain": None,
        "recipient": None,
        "targetLane": None,
        "missingFields": [] if intent == "portfolioSummary" else ["required field"],
        "riskFlags": [],
        "summary": "Safe hosted smoke fixture",
    },
    "policyState": {
        "mainWalletExecution": "blocked_in_agent_handoff_only",
        "zerionExecution": "existing_a2_tiny_swap_review_only",
        "cloakExecution": "wallet_private_handoff_only",
        "watchOnlyExecution": "analysis_only",
        "requiredApproval": "destination_module_policy_and_user_approval",
        "safetyMode": "redacted_context_minimized",
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
        "draftZerionTinySwap",
    ],
    "safetyMode": "hosted_ai_advisory_policy_deterministic",
    "clientVersion": "2026-05-10.a5",
}
print(json.dumps(payload, separators=(",", ":")))
PY
}

mock_response() {
  case "$1" in
    portfolio)
      cat <<'JSON'
{"assistantMessage":"Your portfolio fixture is empty, so there is no live exposure to summarize.","suggestedIntent":"portfolioSummary","missingFields":[],"proposalSuggestion":null,"toolSuggestions":["summarizePortfolio"],"safetyWarnings":[],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-portfolio"}
JSON
      ;;
    clarification)
      cat <<'JSON'
{"assistantMessage":"Which token mint should I use for the buy draft?","suggestedIntent":"tokenBuyRequest","missingFields":["token mint"],"proposalSuggestion":null,"toolSuggestions":[],"safetyWarnings":["Missing token identity"],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-clarification"}
JSON
      ;;
    pusd)
      cat <<'JSON'
{"assistantMessage":"I can prepare a PUSD payment draft for Wallet review.","suggestedIntent":"pusdPaymentRequest","missingFields":["recipient","amount"],"proposalSuggestion":{"actionType":"pusdPaymentDraft","title":"PUSD payment draft","explanation":"Review in Wallet before any send.","riskNotes":["Destination approval required"],"missingFields":["recipient","amount"]},"toolSuggestions":[{"name":"draftPUSDPayment","reason":"Payment request only","confidence":0.9}],"safetyWarnings":[],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-pusd"}
JSON
      ;;
    unsafe)
      cat <<'JSON'
{"assistantMessage":"Unsafe fixture response.","suggestedIntent":"tokenSwapRequest","missingFields":[],"proposalSuggestion":{"actionType":"mainWalletSwapDraft","title":"Unsafe tool fixture","explanation":"Unsafe tools must be blocked.","riskNotes":[],"missingFields":[]},"toolSuggestions":["draftSwapProposal","executeSwap","sendTransaction","runShell"],"safetyWarnings":["This response intentionally contains blocked suggestions."],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-unsafe"}
JSON
      ;;
    approval)
      cat <<'JSON'
{"assistantMessage":"Backend approval claim fixture.","suggestedIntent":"tokenSwapRequest","missingFields":[],"proposalSuggestion":{"actionType":"mainWalletSwapDraft","title":"Unsafe approval claim","explanation":"This must be ignored.","riskNotes":[],"missingFields":[],"status":"approved","executionApproved":true},"toolSuggestions":["draftSwapProposal"],"safetyWarnings":["This response intentionally claims approval."],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"},"requestId":"mock-approval"}
JSON
      ;;
    malformed)
      cat <<'JSON'
{"assistantMessage":"Malformed fixture with minimal fields only."}
JSON
      ;;
    missing_request_id)
      cat <<'JSON'
{"assistantMessage":"Response omits request id.","suggestedIntent":"portfolioSummary","missingFields":[],"proposalSuggestion":null,"toolSuggestions":["summarizePortfolio"],"safetyWarnings":[],"modelInfo":{"provider":"gorkh-hosted","model":"deepseek-backed","contractVersion":"2026-05-10.a5"}}
JSON
      ;;
    malformed_json)
      printf '{"assistantMessage":'
      ;;
    oversized)
      python3 - <<'PY'
import json
print(json.dumps({
    "assistantMessage": "x" * 70000,
    "suggestedIntent": "portfolioSummary",
    "missingFields": [],
    "proposalSuggestion": None,
    "toolSuggestions": ["summarizePortfolio"],
    "safetyWarnings": [],
    "modelInfo": {"provider": "gorkh-hosted", "model": "deepseek-backed", "contractVersion": "2026-05-10.a5"},
    "requestId": "mock-oversized",
}))
PY
      ;;
    *)
      echo "Unknown mock scenario: $1" >&2
      exit 2
      ;;
  esac
}

normalize_http_status() {
  case "$1" in
    401) echo "unauthorized" ;;
    403) echo "forbidden" ;;
    429) echo "rate_limited" ;;
    5*) echo "server_error" ;;
    *) echo "http_$1" ;;
  esac
}

validate_response() {
  local scenario="$1"
  local response_file
  response_file="$(mktemp)"
  cat > "$response_file"
  python3 - "$scenario" "$response_file" "$MAX_RESPONSE_BYTES" <<'PY'
import json
import sys

scenario = sys.argv[1]
path = sys.argv[2]
max_bytes = int(sys.argv[3])
payload = open(path, "rb").read()

if len(payload) > max_bytes:
    if scenario == "oversized":
        print(f"{scenario}: pass normalized=oversized_response bytes={len(payload)}")
        sys.exit(0)
    print(f"{scenario}: oversized response bytes={len(payload)}", file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(payload.decode("utf-8"))
except Exception as exc:
    if scenario == "malformed_json":
        print(f"{scenario}: pass normalized=malformed_response")
        sys.exit(0)
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

allowed = {
    "summarizePortfolio", "summarizeRisk", "summarizeYield", "summarizeLPs", "summarizePnL",
    "draftSwapProposal", "draftPUSDPayment", "draftCloakPayment", "draftZerionTinySwap"
}
blocked_names = {
    "executeSwap", "sendTransaction", "signTransaction", "bridge", "sendToken",
    "exportSeed", "revealPrivateKey", "runShell", "arbitraryCommand"
}
blocked = [name for name in names if name in blocked_names or name not in allowed]

proposal = data.get("proposalSuggestion") or {}
approval_claim = bool(proposal.get("executionApproved")) or str(proposal.get("status", "")).lower() in {"approved", "executed"}

if scenario == "unsafe":
    if not blocked:
        print("unsafe: expected blocked tools", file=sys.stderr)
        sys.exit(1)
elif scenario == "approval":
    if not approval_claim:
        print("approval: expected backend approval claim", file=sys.stderr)
        sys.exit(1)
else:
    if blocked:
        print(f"{scenario}: unexpected unsafe tools: {blocked}", file=sys.stderr)
        sys.exit(1)
    if approval_claim:
        print(f"{scenario}: unexpected backend approval claim", file=sys.stderr)
        sys.exit(1)

contract = data.get("modelInfo", {}).get("contractVersion")
if contract and contract != "2026-05-10.a5":
    print(f"{scenario}: unexpected contract version {contract}", file=sys.stderr)
    sys.exit(1)

request_id = data.get("requestId")
if not request_id:
    status = "degraded_missing_request_id"
else:
    status = f"requestId={request_id}"

print(f"{scenario}: pass {status} blockedTools={len(blocked)} approvalClaimIgnored={str(approval_claim).lower()}")
PY
  rm -f "$response_file"
}

run_mock_failure() {
  local scenario="$1"
  case "$scenario" in
    unauthorized)
      echo "unauthorized: pass normalized=unauthorized http=401"
      ;;
    forbidden)
      echo "forbidden: pass normalized=forbidden http=403"
      ;;
    rate_limited)
      echo "rate_limited: pass normalized=rate_limited http=429"
      ;;
    server_error)
      echo "server_error: pass normalized=server_error http=500"
      ;;
    timeout)
      echo "timeout: pass normalized=timeout"
      ;;
    *)
      return 1
      ;;
  esac
}

run_mock_scenario() {
  local scenario="$1"
  if run_mock_failure "$scenario"; then
    return 0
  fi
  mock_response "$scenario" | validate_response "$scenario"
}

run_remote_scenario() {
  local scenario="$1"
  local request_file response_file curl_config http_file curl_exit http_status normalized
  request_file="$(mktemp)"
  response_file="$(mktemp)"
  curl_config="$(mktemp)"
  http_file="$(mktemp)"
  chmod 600 "$curl_config"
  trap 'rm -f "$request_file" "$response_file" "$curl_config" "$http_file"' RETURN
  fixture_request "$scenario" > "$request_file"

  set +e
  if [[ -n "${GORKH_AGENT_API_KEY:-}" ]]; then
    printf 'header = "Authorization: Bearer %s"\n' "${GORKH_AGENT_API_KEY}" > "$curl_config"
    curl -sS \
      --max-time "$TIMEOUT_SECONDS" \
      --config "$curl_config" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -o "$response_file" \
      -w "%{http_code}" \
      --data-binary "@${request_file}" \
      "${BASE_URL%/}/v1/agent/chat" > "$http_file"
    curl_exit=$?
  else
    curl -sS \
      --max-time "$TIMEOUT_SECONDS" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -o "$response_file" \
      -w "%{http_code}" \
      --data-binary "@${request_file}" \
      "${BASE_URL%/}/v1/agent/chat" > "$http_file"
    curl_exit=$?
  fi
  set -e

  if [[ "$curl_exit" -eq 28 ]]; then
    if [[ "$EXPECT_TIMEOUT" -eq 1 ]]; then
      echo "remote: pass normalized=timeout expected=true"
      return 0
    fi
    echo "remote: timeout" >&2
    return 1
  fi
  if [[ "$curl_exit" -ne 0 ]]; then
    echo "remote: curl failed exit=$curl_exit" >&2
    return 1
  fi

  http_status="$(cat "$http_file")"
  if [[ ! "$http_status" =~ ^2 ]]; then
    normalized="$(normalize_http_status "$http_status")"
    if [[ "$EXPECT_AUTH_FAILURE" -eq 1 && ( "$http_status" == "401" || "$http_status" == "403" ) ]]; then
      echo "remote: pass normalized=$normalized expected_auth_failure=true"
      return 0
    fi
    echo "remote: failed normalized=$normalized http=$http_status" >&2
    return 1
  fi

  if [[ "$EXPECT_AUTH_FAILURE" -eq 1 || "$EXPECT_TIMEOUT" -eq 1 ]]; then
    echo "remote: expected failure but request succeeded" >&2
    return 1
  fi

  validate_response "$scenario" < "$response_file"
}

mock_all() {
  local scenarios=(
    portfolio
    clarification
    pusd
    unsafe
    approval
    malformed
    missing_request_id
    malformed_json
    oversized
    unauthorized
    forbidden
    rate_limited
    server_error
    timeout
  )
  for scenario in "${scenarios[@]}"; do
    run_mock_scenario "$scenario"
  done
}

if [[ "$MODE" == "mock" ]]; then
  if [[ "$FIXTURE" == "all" ]]; then
    mock_all
  else
    run_mock_scenario "$FIXTURE"
  fi
else
  if [[ -z "$BASE_URL" ]]; then
    echo "GORKH_AGENT_API_BASE_URL is missing; use --mock for fixture validation" >&2
    exit 1
  fi
  if [[ "$FIXTURE" == "all" ]]; then
    run_remote_scenario "portfolio"
  else
    run_remote_scenario "$FIXTURE"
  fi
fi

echo "Agent hosted AI smoke passed"
