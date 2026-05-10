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

Approval screens include "Open in Transaction Studio." The handoff sends a safe summary only unless a future flow explicitly provides an in-memory temporary payload. Raw transaction bytes are not persisted by Shield Review.

## Non-Goals

- No external dApp signing.
- No Transaction Studio broadcast.
- No arbitrary RPC console.
- No new execution flows.
- No approval gate weakening.
