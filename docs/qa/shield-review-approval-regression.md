# Shield Review Approval Regression

Use this checklist for fixture, devnet, or manual mainnet approval QA. Shield Review is review-only: it must not sign, broadcast, or move funds. Execution stays inside the existing destination approval flow.

## Global Expectations

- Shield Review card appears before final approval where transaction data or a safe summary exists.
- Card shows status, risk level, recognized action, programs, signer count, writable count, unknown instruction count, simulation state, and payload mode.
- Transaction Studio handoff shows `Exact transaction`, `Summary only`, or `Unavailable`.
- Exact handoff is transient and in-memory only. Its raw payload is not persisted to Studio history, logs, Agent, or hosted AI.
- Summary-only states are honest and do not fake raw decode.
- Existing gates remain active: wallet unlock, watch-only block, simulation policy, draft fingerprint, mainnet phrase, LocalAuthentication, and audit logging.

## SOL Send Approval

- Setup: prepare a small SOL transfer draft and run the existing approval preflight.
- Expected card: System Program, System transfer, SOL transfer risk flag, one signer, source/destination writable state.
- Expected risk: medium on mainnet or if simulation is missing/failed; otherwise low/medium depending on destination and network.
- Expected simulation: shows success/failure/unavailable from existing preflight.
- Expected approval gate: simulation failure blocks when the flow requires simulation; mainnet phrase remains required on mainnet.
- Expected Studio handoff: exact transaction when the prepared message is still in memory; summary-only after expiry/restart.
- Execution status: fixture-only or devnet-only unless a manual mainnet smoke is explicitly approved.

## SPL Token Send Approval

- Setup: prepare a token transfer. Include a missing recipient token account case when possible.
- Expected card: SPL Token or Token-2022, transferChecked/transfer action, optional Associated Token Account creation.
- Expected risk: token movement warning; Token-2022 hook/fee warnings when applicable.
- Expected simulation: existing token-send preflight status.
- Expected approval gate: watch-only wallet blocks; simulation policy and mainnet phrase remain active.
- Expected Studio handoff: exact transaction when the prepared token message is in memory.
- Execution status: fixture-only or devnet-only unless manually approved.

## Token-2022 Send Approval

- Setup: use a Token-2022 fixture or devnet mint if available.
- Expected card: Token-2022 program, transferChecked/transfer action, extension warnings when extension data is unavailable.
- Expected risk: medium when hook/fee extension status is unknown.
- Expected simulation: success/failure/unavailable displayed honestly.
- Expected approval gate: same as SPL token send.
- Expected Studio handoff: exact transaction if prepared message exists; otherwise summary-only.
- Execution status: fixture-only unless a safe devnet fixture exists.

## Jupiter Swap Approval

- Setup: quote/build a tiny swap and reach the review screen.
- Expected card: Jupiter route, token movement summary if detectable, ALT use if present, signer/writable counts.
- Expected risk: DeFi route warning, high/medium if unknown writable programs or simulation failed.
- Expected simulation: existing swap simulation and quote freshness/fingerprint checks remain visible.
- Expected approval gate: stale quote, fingerprint mismatch, or failed required simulation blocks approval.
- Expected Studio handoff: exact transaction when the built Jupiter transaction is in memory; never persisted.
- Execution status: fixture-only/devnet-only unless manually approved.

## Orca Harvest Approval

- Setup: use an owned position fixture or manual wallet with an Orca position.
- Expected card: Orca Whirlpool/protocol interaction, writable/instruction counts, rewards/fees summary if available.
- Expected risk: DeFi protocol interaction; unknown instruction warning if exact parser cannot recognize a harvest instruction.
- Expected simulation: existing Orca simulation state.
- Expected approval gate: current Orca harvest approval gates remain unchanged.
- Expected Studio handoff: exact transaction when the harvest message is available; otherwise summary-only.
- Execution status: manual only with owned LP position.

## Cloak Deposit Approval Summary

- Setup: prepare a Cloak deposit draft.
- Expected card: Cloak program/private-state warning, real-mainnet warning, no proof inputs or private state exposed.
- Expected risk: high unless the flow has enough live validation to lower it.
- Expected simulation: unavailable or current Cloak preflight status, shown honestly.
- Expected approval gate: existing Cloak approval and local-state requirements remain unchanged.
- Expected Studio handoff: summary-only unless only a safe raw transaction payload is already available.
- Execution status: manual mainnet-only.

## Cloak Full Withdraw / Private Pay Summary

- Setup: prepare a full withdraw or private payment draft.
- Expected card: Cloak interaction, local private state warning, no viewing key, nullifier, proof input, or vault secret.
- Expected risk: high or unknown if exact payload is unavailable.
- Expected simulation: current flow state, or unavailable with reason.
- Expected approval gate: existing Cloak approval gates remain.
- Expected Studio handoff: summary-only by default.
- Execution status: manual mainnet-only.

## Zerion Tiny Swap Summary

- Setup: open an A2 Zerion tiny swap review with missing or configured prerequisites.
- Expected card: separate Zerion wallet, scoped policy, redacted command preview, no GORKH main-wallet access.
- Expected risk: blocked until CLI/API key/agent token/policy and exact approval phrase requirements pass.
- Expected simulation: external summary only unless Zerion CLI exposes safe raw transaction data before execution.
- Expected approval gate: existing Zerion policy and phrase gates remain.
- Expected Studio handoff: summary-only; do not fake raw decode.
- Execution status: manual only with separate tiny-funded Zerion wallet.

## High-Risk / Unknown Instruction Fixture

- Setup: use a raw transaction fixture containing an unknown program or many writable accounts.
- Expected card: unknown instruction count visible, unknown program risk flag, writable-account warning if threshold is exceeded.
- Expected risk: high or unknown depending on the fixture.
- Expected simulation: failed/unavailable shown honestly if RPC cannot simulate.
- Expected approval gate: if review is required and internal review failed, approval remains blocked.
- Expected Studio handoff: exact if fixture payload is transiently available.
- Execution status: fixture-only.

## Simulation Failure / Unavailable Fixture

- Setup: use a transaction with stale blockhash, failed simulation, or RPC unavailable state.
- Expected card: simulation failed/unavailable risk flag.
- Expected risk: high when simulation is required and failed.
- Expected approval gate: approval blocked when the destination policy requires simulation.
- Expected Studio handoff: exact or summary depending on payload availability.
- Execution status: fixture-only.

## Mainnet Phrase State

- Setup: run any approval flow on mainnet.
- Expected card: mainnet risk/real-funds context remains visible.
- Expected approval gate: exact mainnet phrase remains required before signing.
- Expected Studio handoff: does not satisfy the mainnet phrase requirement.
- Execution status: manual only.

## Locked Wallet State

- Setup: lock the wallet and open a pending approval state if available.
- Expected card: Shield Review may show summary, but approval controls remain disabled behind unlock.
- Expected approval gate: wallet unlock and LocalAuthentication remain required.
- Expected Studio handoff: summary/exact review may be available, but cannot sign from Studio.
- Execution status: not run.

## Watch-Only Blocked State

- Setup: set a watch-only wallet active and attempt a send/swap/private action.
- Expected card: no executable approval path; clear watch-only explanation.
- Expected approval gate: signing is blocked.
- Expected Studio handoff: summary-only if a safe proposal summary exists.
- Execution status: not run.
