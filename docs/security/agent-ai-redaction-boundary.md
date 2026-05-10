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
