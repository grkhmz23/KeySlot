# Lending Dashboard

Phase 3.4 adds a read-only lending dashboard inside Wallet -> Portfolio. It is portfolio intelligence only.

## Scope

- Protocol cards for Kamino and MarginFi.
- Safe models for supplied assets, borrowed assets, net value, LTV, health factor, liquidation threshold, risk level, and adapter status.
- Portfolio summaries include position count, supplied value, borrowed value, net lending value, risky position count, and unavailable adapter count.
- Lending values are shown separately from wallet token balances to avoid double-counting.

## Execution Boundary

The dashboard does not request signing and does not build transactions. Deposit, borrow, repay, and withdraw actions are locked. Future execution must be a separate phase with draft, risk review, simulation, explicit approval, LocalAuthentication, native signing, confirmation, and audit.

No transaction builders, action builders, serialized transactions, instruction payloads, private keys, seed phrases, mnemonics, signing seeds, or wallet JSON are used by the lending dashboard.

## Adapter Status

The initial Kamino and MarginFi adapters are explicit read-only placeholders. They return `unavailable` with a reason because no reviewed public endpoint or audited SDK read-only path is configured in the app yet. This is intentional: GORKH must not fake positions or pull in SDKs that expose transaction-building helpers without a separate security review.

## Safe Storage

Snapshots may store only public wallet addresses, protocol names, supplied/borrowed/net value summaries, risk counts, adapter statuses, timestamps, and error/unavailable state. They must not store wallet secrets or executable payloads.

## Future Read-Only Integration Requirements

A future Kamino or MarginFi live read-only adapter must prove:

- it can discover positions by public wallet address without private keys,
- it does not call deposit, borrow, repay, withdraw, liquidation, or transaction-builder APIs,
- it does not persist raw protocol accounts containing sensitive or executable data,
- it exposes unavailable/error states honestly,
- tests prove no signing or transaction payload path was added.
