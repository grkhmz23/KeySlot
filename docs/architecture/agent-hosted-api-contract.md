# Agent Hosted API Contract

Phase A5 defines the backend contract between the native macOS Agent and the GORKH Hosted Agent API backed by DeepSeek.

The macOS app calls only the GORKH hosted endpoint. The backend holds any model-provider secret. Users do not bring model API keys, and the app does not store provider credentials.

## Endpoint

`POST /v1/agent/chat`

The base URL is configured locally with `GORKH_AGENT_API_BASE_URL`. If backend authentication is required, `GORKH_AGENT_API_KEY` is optional and env-only. Neither value belongs in Xcode schemes, screenshots, logs, or committed files.

## Request

```json
{
  "conversationId": "uuid",
  "messageId": "uuid",
  "userMessage": "redacted user text",
  "redactedContext": {},
  "deterministicIntent": {},
  "policyState": {},
  "allowedTools": ["summarizePortfolio"],
  "safetyMode": "hosted_ai_advisory_policy_deterministic",
  "clientVersion": "2026-05-10.a5"
}
```

The app validates outbound requests before sending:

- context is minimized and size bounded,
- tools are drawn from the local allowlist,
- forbidden secret-like fields are blocked,
- transaction payloads and raw wallet internals are blocked,
- wallet addresses are shortened or already public-facing.

## Response

```json
{
  "assistantMessage": "safe explanation",
  "suggestedIntent": "portfolioSummary",
  "missingFields": [],
  "proposalSuggestion": {
    "actionType": "mainWalletSwapDraft",
    "title": "Review swap draft",
    "explanation": "Open Wallet -> Swap for review.",
    "riskNotes": [],
    "missingFields": []
  },
  "toolSuggestions": [
    {"name": "summarizePortfolio", "reason": "read-only"}
  ],
  "safetyWarnings": [],
  "modelInfo": {
    "provider": "gorkh-hosted",
    "model": "deepseek-backed",
    "contractVersion": "2026-05-10.a5"
  },
  "requestId": "backend-request-id"
}
```

All response fields are advisory. The backend cannot approve execution, cannot bypass policy, and cannot change a proposal into an approved state. If a response claims approval or execution, the app ignores that claim and treats the response as degraded.

## Tool Boundary

Allowed tool suggestions:

- `summarizePortfolio`
- `summarizeRisk`
- `summarizeYield`
- `summarizeLPs`
- `summarizePnL`
- `draftSwapProposal`
- `draftPUSDPayment`
- `draftCloakPayment`
- `draftZerionTinySwap`

Blocked suggestions include execution, signing, shell, secret export, bridge, direct send, and arbitrary command tools. Blocked tool suggestions are audited as safe summaries only.

## Execution Authority

The hosted API has no execution authority.

Main Wallet actions remain handoff-only into Wallet modules. Zerion actions remain routed through the existing policy-scoped Zerion tiny-swap review. Cloak actions remain routed to Wallet -> Private. Every execution path still requires the destination module's review, simulation where applicable, explicit approval, and existing security gates.
