# Lending Dashboard

Phase 3.4 adds a read-only lending dashboard inside Wallet -> Portfolio. Phase 3.4B wires Kamino to reviewed read-only public API data where safe. It remains portfolio intelligence only.

## Scope

- Protocol cards for Kamino and MarginFi.
- Safe models for supplied assets, borrowed assets, net value, LTV, health factor, liquidation threshold, risk level, and adapter status.
- Portfolio summaries include position count, supplied value, borrowed value, net lending value, risky position count, unavailable adapter count, and read-only market reserve count.
- Lending values are shown separately from wallet token balances to avoid double-counting.

## Execution Boundary

The dashboard does not request signing and does not build transactions. Deposit, borrow, repay, and withdraw actions are locked. Future execution must be a separate phase with draft, risk review, simulation, explicit approval, LocalAuthentication, native signing, confirmation, and audit.

No transaction builders, action builders, unsigned transaction endpoints, serialized transactions, instruction payloads, private keys, seed phrases, mnemonics, signing seeds, or wallet JSON are used by the lending dashboard.

## Adapter Status

Kamino uses the official public API at `https://api.kamino.finance` through an explicit read-only allowlist:

- `GET /v2/kamino-market`
- `GET /kamino-market/{marketPubkey}/reserves/metrics?env=mainnet-beta`
- `GET /kamino-market/{marketPubkey}/users/{userPubkey}/obligations?env=mainnet-beta`

The adapter fetches mainnet-beta market configs, reserve metrics for market context, and user obligations by public wallet address. If obligations are returned, GORKH normalizes aggregate supplied value, borrowed value, net account value, LTV, and nonzero reserve entries into safe lending models. If the wallet has no returned obligations, the adapter reports `empty`. If market data loads but obligation lookup fails, the adapter reports stale partial data instead of fake positions.

MarginFi remains an explicit read-only placeholder and returns `unavailable` until a reviewed public endpoint or audited SDK read-only path is configured.

## Endpoint Guard

Kamino endpoints are rejected unless their path exactly matches the allowlist above and all market/user path parameters are valid Solana public keys. The guard blocks paths containing:

- transaction, unsignedtransaction, txn, tx
- deposit, borrow, repay, withdraw, liquidate
- leverage, multiply, swap, order, action, instruction

These blocked words may still appear in UI labels or docs as locked/forbidden actions; they must not appear as executable endpoint paths.

## Safe Storage

Snapshots may store only public wallet addresses, protocol names, supplied/borrowed/net value summaries, risk counts, market reserve counts, adapter statuses, timestamps, and error/unavailable state. They must not store wallet secrets or executable payloads.

## Future Read-Only Integration Requirements

A future MarginFi live read-only adapter or broader Kamino market coverage must prove:

- it can discover positions by public wallet address without private keys,
- it does not call deposit, borrow, repay, withdraw, liquidation, or transaction-builder APIs,
- it does not persist raw protocol accounts containing sensitive or executable data,
- it exposes unavailable/error states honestly,
- tests prove no signing or transaction payload path was added.
