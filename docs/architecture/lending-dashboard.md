# Lending Dashboard

Phase 3.4 adds a read-only lending dashboard inside Wallet -> Portfolio. Phase 3.4B wires Kamino to reviewed read-only public API data where safe. Phase 3.4C adds a strict MarginFi read-only adapter boundary. It remains portfolio intelligence only.

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

MarginFi uses the official protocol docs and program address:

- Docs: `https://docs.marginfi.com/`
- TypeScript SDK docs: `https://docs.marginfi.com/ts-sdk`
- Program docs: `https://docs.marginfi.com/mfi-v2`
- Mainnet-beta program: `MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA`
- Main group: `4qp6Fx6tnZkY5Wropq9wUYgtFxXKwE6viZxFHg3rdAG8`

The MarginFi adapter performs only a read-only Solana RPC `getAccountInfo` status check for the official v2 program account on mainnet-beta. Wallet position parsing remains `unavailable` because the reviewed docs do not provide a safe REST user-position endpoint, and the SDK examples include account creation and lending actions that are not allowed in this phase. The UI must state that read-only MarginFi position parsing is not connected yet and that no funds are touched.

## Endpoint Guard

Kamino endpoints are rejected unless their path exactly matches the allowlist above and all market/user path parameters are valid Solana public keys. The guard blocks paths containing:

- transaction, unsignedtransaction, txn, tx
- deposit, borrow, repay, withdraw, liquidate
- leverage, multiply, swap, order, action, instruction

These blocked words may still appear in UI labels or docs as locked/forbidden actions; they must not appear as executable endpoint paths.

MarginFi has no HTTP endpoint allowlist in Phase 3.4C. Any MarginFi HTTP path is rejected after denylist checking. The only allowlisted MarginFi RPC method is:

- `getAccountInfo`

The MarginFi guard blocks HTTP paths or RPC method names containing:

- transaction, unsignedtransaction, txn, tx, instruction
- create, account-create
- deposit, borrow, repay, withdraw, liquidate
- leverage, multiply, loop, swap, order, action

## Safe Storage

Snapshots may store only public wallet addresses, protocol names, supplied/borrowed/net value summaries, risk counts, market reserve counts, adapter statuses, per-protocol adapter statuses, timestamps, and error/unavailable state. They must not store wallet secrets or executable payloads.

## Future Read-Only Integration Requirements

A future MarginFi live position parser or broader Kamino market coverage must prove:

- it can discover positions by public wallet address without private keys,
- it does not call account creation, deposit, borrow, repay, withdraw, liquidation, leverage, or transaction-builder APIs,
- it does not persist raw protocol accounts containing sensitive or executable data,
- it exposes unavailable/error states honestly,
- tests prove no signing or transaction payload path was added.
