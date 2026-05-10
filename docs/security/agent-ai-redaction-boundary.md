# Agent AI Redaction Boundary

The hosted Agent path is intentionally smaller than the Wallet data model. The app builds a minimized context, validates it, and blocks the request if forbidden data is detected.

## Forbidden Outbound Data

The app must not send:

- wallet recovery words or signer material,
- wallet JSON,
- API keys or Zerion automation credentials,
- Cloak private vault material,
- nullifier or proof input data,
- serialized or unsigned transaction payloads,
- raw audit JSON,
- Xcode scheme environment values,
- local filesystem paths containing sensitive material.

## Allowed Context

Allowed context is limited to:

- shortened public wallet address,
- wallet/network status,
- aggregate portfolio value and counts,
- PUSD treasury summary,
- yield and liquidity summary counts,
- PnL status and non-accounting disclaimer,
- recent safe activity labels,
- Zerion status labels,
- policy state and allowed advisory tools.

## Validation Layers

1. User message redaction blocks secret-like text before a hosted request is built.
2. Context validation encodes the payload and scans for forbidden fields.
3. Contract validation checks context size and tool allowlists.
4. Response sanitization blocks unsafe tool suggestions and ignores backend approval claims.
5. Deterministic policy validation remains authoritative before any proposal handoff.

## Remote Smoke Boundary

`scripts/agent-hosted-ai-smoke.sh --remote` sends only a fixture context with a watch-only display wallet, empty portfolio summary, empty activity list, and allowed advisory tool names. It does not read the real app wallet store, Keychain, private vault, Xcode schemes, shell history, or local project paths.

The script reports endpoint host and auth presence as redacted status only. If `GORKH_AGENT_API_KEY` is present, the value is passed through a temporary curl config file and removed after the request; it is not printed.

Failure-mode fixtures verify that authentication failures, rate limits, server errors, timeouts, malformed responses, unsafe tool suggestions, approval claims, missing request ids, and oversized responses all remain non-executing states.

## Audit Boundary

Audit events store only safe summaries:

- hosted request prepared,
- contract validated,
- request blocked by redaction,
- response received,
- fallback used,
- unsafe backend suggestion blocked,
- malformed advisory response ignored.

Prompt bodies and raw hosted responses are not stored as audit details.
