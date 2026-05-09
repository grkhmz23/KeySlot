# Jupiter Swap Compatibility

Phase 3.3 uses Jupiter Metis Swap API v1 in compatibility mode:

- `GET /swap/v1/quote` for route quotes.
- `POST /swap/v1/swap` for an unsigned serialized transaction.
- GORKH decodes, reviews, simulates, approves, signs locally, and sends through the selected Solana RPC.
- The serialized transaction is kept only in memory for the current draft and is not written to UserDefaults, audit logs, or files.

Jupiter's current docs say Metis Swap API v1 is no longer actively maintained and has been superseded by Swap V2. GORKH must therefore treat v1 as a compatibility path, not the long-term target.

## Swap V2 Paths To Review

Jupiter Swap V2 has two relevant paths:

- Meta-Aggregator: `GET /swap/v2/order` plus `POST /swap/v2/execute`.
- Router: `GET /swap/v2/build` plus self-managed RPC send or `POST /tx/v1/submit`.

The Meta-Aggregator path returns a base64 unsigned transaction plus a `requestId`. After native signing, `/execute` receives the signed transaction and request id, and Jupiter handles managed landing. The Router path returns raw instructions and address lookup table data for a locally assembled transaction.

## Migration Risks

- `requestId` and order expiry must be bound to the reviewed draft.
- `/execute` changes the landing model from native RPC send to Jupiter-managed execution.
- JupiterZ RFQ routes may require partial signing because a market-maker signature is added during `/execute`.
- Router `/build` returns instructions, not a ready transaction, so native transaction assembly and address lookup table handling must be implemented separately.
- Route/program allowlists need review for all V2 routers: Metis, JupiterZ, Dflow, and OKX.
- Balance-delta verification must confirm input/output effects after confirmation where possible.
- API key and rate-limit behavior must remain env-only and redacted.
- No limit-order, trigger, recurring, lending, perps, or unrelated Jupiter endpoints should be reachable from Wallet Swap.

## Recommended Migration Path

1. Keep current Metis v1 flow visible as "Metis v1 compatibility mode."
2. Add non-executing endpoint compatibility checks for `/swap/v2/order`, `/swap/v2/execute`, `/swap/v2/build`, and `/tx/v1/submit`.
3. Prototype V2 decode/review using fixture responses only.
4. Decide between Meta-Aggregator managed landing and Router native assembly.
5. For Meta-Aggregator, require a signer policy update for partial signatures and `/execute` response verification.
6. For Router, implement native instruction assembly, ALT resolution, simulation, signing, and self-managed send before enabling.
7. Run a tiny manually approved mainnet validation only after V2 review, route risk checks, balance-delta verification, API key redaction, and audit coverage pass.

## Current Policy

Phase 3.3B does not execute Swap V2 and does not call `/order`, `/execute`, `/build`, `/submit`, limit-order, trigger, recurring, lending, or perps endpoints. Those endpoints are documented and guarded as future candidates only.
