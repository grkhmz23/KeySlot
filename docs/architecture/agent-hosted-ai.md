# Agent Hosted AI

Phase A4 adds a hosted AI layer to Agent Chat while keeping the deterministic Wallet operator as the authority for proposals and policy.

## Provider

The macOS app calls a GORKH Hosted Agent API backed by DeepSeek. Users do not bring a model key, and the app does not include a provider secret.

Local configuration:

- `GORKH_AGENT_API_BASE_URL`
- optional `GORKH_AGENT_API_KEY` for app-to-backend authentication

`GORKH_AGENT_API_BASE_URL` must be an HTTPS URL. Non-HTTPS values are treated as unavailable and fall back to local safe mode.

The request path is:

`POST /v1/agent/chat`

If the hosted endpoint is not configured or fails, Agent Chat falls back to local safe mode. The deterministic intent classifier, local policy engine, and proposal handoff model continue to work.

## Request Boundary

Before every hosted request, GORKH:

- runs the deterministic intent classifier,
- builds a minimized context,
- redacts user text,
- blocks known forbidden fields,
- attaches safety metadata,
- includes only allowed local tool names.

Allowed context is limited to public and summarized data:

- redacted wallet address display,
- wallet kind and network,
- aggregate portfolio value and status,
- PUSD treasury and circulation status,
- yield, liquidity, and PnL summaries,
- recent safe activity labels,
- redacted Zerion readiness status,
- security/RPC status.

Forbidden content is never sent:

- recovery text, private keys, wallet files, signing material,
- API keys or Zerion token material,
- Cloak private records, viewing keys, nullifiers, proof inputs,
- transaction payloads or unsigned/signed serialized transactions,
- full raw audit JSON.

## AI Merge Rules

The hosted response can improve:

- explanation text,
- clarifying questions,
- proposal copy,
- risk wording,
- missing-field wording.

The hosted response cannot approve, execute, sign, or change deterministic execution fields. Any executable request still becomes a local proposal and must pass `AgentPolicyEngine`.

## Tool Boundary

Allowed AI tool suggestions:

- `summarizePortfolio`
- `summarizeRisk`
- `summarizeYield`
- `summarizeLPs`
- `summarizePnL`
- `draftSwapProposal`
- `draftPUSDPayment`
- `draftCloakPayment`
- `draftZerionTinySwap`

Execution, shell, secret-export, bridge, send, sign, and arbitrary command suggestions are blocked and audited.

## UI

Agent Chat shows:

- Hosted DeepSeek or Local Safe Mode,
- provider status,
- redaction status,
- "No secrets sent" indicator,
- fallback reason when the hosted endpoint is unavailable.

## Audit

A4 adds safe Agent audit events for hosted request preparation, redaction blocks, hosted responses, fallback, local safe mode, accepted AI draft copy, and blocked AI tool suggestions. Prompt bodies and secrets are not stored.
