# Shield Review Integration

Shield Review integrates Transaction Studio's local review concepts into existing approval screens.

It is review-only. It cannot sign, broadcast, request an airdrop, create bundles, or move funds. Existing destination flows still own signing and sending:

- Wallet SOL send
- Wallet token send
- Jupiter swap
- Orca harvest
- Cloak deposit / full withdraw
- Zerion tiny swap review

## Flow

Approval flows now follow:

1. Draft or proposal exists.
2. Shield Review summarizes the action, programs, signers, writable accounts, simulation status, risk flags, and explanation.
3. The destination approval screen keeps its existing simulation, mainnet phrase, fingerprint, unlock, LocalAuthentication, and audit gates.
4. User approval remains required before any existing signer path can run.

Shield Review never receives wallet secret material. It uses only public addresses, program labels, safe parsed actions, simulation status, and redacted summaries.

## Transaction Studio Reuse

When decoded transaction data is available, Shield Review maps Transaction Studio output:

- decoded instructions
- parser status
- known program labels
- risk flags
- deterministic explanation
- simulation state

When raw bytes are not safely available, Shield Review returns an honest summary:

- Cloak: private proof and local vault details are not exposed.
- Zerion: external CLI summary is shown; raw transaction decode is unavailable.

## Handoff

Approval screens include an "Open in Transaction Studio" action with an explicit payload mode:

- `Exact transaction`: the approval flow already has transaction/message bytes in memory and Shield Review can pass a temporary base64 transaction to Studio.
- `Summary only`: the flow can provide a safe summary, but raw bytes are not available or not safe to expose.
- `Unavailable`: payload validation failed or the temporary payload expired.

Exact handoffs are transient and in-memory only. They expire after a short window, are not written to Studio history, are not logged, and are not sent to Agent or hosted AI. If the app restarts or the handoff expires, Transaction Studio falls back to summary-only review.

Current payload fidelity:

- SOL send: exact handoff when the prepared message is available.
- SPL token send: exact handoff when the prepared token-transfer message is available.
- Jupiter swap: exact handoff when the already-built Jupiter transaction is in memory.
- Orca harvest: exact handoff when the harvest message is available before approval.
- Cloak: summary-only unless a future flow can expose only a transaction payload without private proof inputs or local private state.
- Zerion: summary-only unless the CLI exposes a safe raw transaction before execution. GORKH does not fake decode external Zerion execution summaries.

## Non-Goals

- No external dApp signing.
- No Transaction Studio broadcast.
- No arbitrary RPC console.
- No new execution flows.
- No approval gate weakening.
