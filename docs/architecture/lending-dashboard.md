# Lending Dashboard

Phase 3.4 adds a read-only lending dashboard inside Wallet -> Portfolio. Phase 3.4B wires Kamino to reviewed read-only public API data where safe. Phase 3.4C adds a strict MarginFi read-only adapter boundary. Phase 3.4D adds an audited read-only MarginFi on-chain account parser for fields whose layout is confirmed from official sources. It remains portfolio intelligence only.

## Scope

- Protocol cards for Kamino and MarginFi.
- Safe models for supplied assets, borrowed assets, net value, LTV, health factor, liquidation threshold, risk level, and adapter status.
- Portfolio summaries include position count, supplied value, borrowed value, net lending value, risky position count, partial adapter count, supplied/borrowed position slot counts, unavailable adapter count, and read-only market reserve count.
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

The MarginFi adapter performs:

- a read-only Solana RPC `getAccountInfo` status check for the official v2 program account on mainnet-beta,
- bounded `getProgramAccounts` discovery using the official account size and authority memcmp filter,
- local parsing of public account data only after owner, discriminator, and authority checks pass.

Official layout sources reviewed:

- `docs.marginfi.com/mfi-v2` for the v2 program ID and instruction authority requirements.
- Official `mrgnlabs/marginfi-v2` source:
  - `type-crate/src/constants.rs` for the `ACCOUNT` discriminator `[67, 178, 130, 109, 126, 114, 28, 42]`.
  - `type-crate/src/types/user_account.rs` for `MarginfiAccount` size `2304`, group offset, authority offset, `LendingAccount`, and 16 `Balance` slots.
  - `programs/marginfi/tests/fixtures/marginfi_account/*.json` for public raw account fixture shape.

Parsed fields:

- account owner must be the official v2 program ID,
- 8-byte Anchor discriminator,
- group public key,
- authority public key,
- account flags,
- active balance slots,
- bank public key per slot,
- supplied/borrowed/unknown side from nonzero asset/liability share bytes,
- balance tag and last update.

Intentionally not parsed in Phase 3.4D:

- bank token mint metadata,
- I80F48 share-to-token amount conversion,
- oracle prices,
- USD values,
- LTV and health factor,
- liquidation/risk math.

When accounts are found, MarginFi returns `partial`: GORKH shows account count and supplied/borrowed share-slot counts, but leaves values and health unavailable. If no accounts are found, MarginFi returns `empty`. If the layout check fails, it returns `error` without showing fake positions.

## Endpoint Guard

Kamino endpoints are rejected unless their path exactly matches the allowlist above and all market/user path parameters are valid Solana public keys. The guard blocks paths containing:

- transaction, unsignedtransaction, txn, tx
- deposit, borrow, repay, withdraw, liquidate
- leverage, multiply, swap, order, action, instruction

These blocked words may still appear in UI labels or docs as locked/forbidden actions; they must not appear as executable endpoint paths.

MarginFi has no HTTP endpoint allowlist in Phase 3.4D. Any MarginFi HTTP path is rejected after denylist checking. The only allowlisted MarginFi RPC methods are:

- `getAccountInfo`
- `getProgramAccounts`

The MarginFi guard blocks HTTP paths or RPC method names containing:

- transaction, unsignedtransaction, txn, tx, instruction
- create, account-create
- deposit, borrow, repay, withdraw, liquidate
- leverage, multiply, loop, swap, order, action

## Safe Storage

Snapshots may store only public wallet addresses, protocol names, supplied/borrowed/net value summaries, risk counts, partial adapter counts, supplied/borrowed position slot counts, market reserve counts, adapter statuses, per-protocol adapter statuses, timestamps, and error/unavailable state. They must not store wallet secrets, raw account data, or executable payloads.

## Future Read-Only Integration Requirements

A future MarginFi value/health parser or broader Kamino market coverage must prove:

- it can discover positions by public wallet address without private keys,
- it does not call account creation, deposit, borrow, repay, withdraw, liquidation, leverage, or transaction-builder APIs,
- it can decode bank metadata, I80F48 shares, oracle prices, value, and health from audited read-only layouts,
- it does not persist raw protocol accounts or executable data,
- it exposes unavailable/error states honestly,
- tests prove no signing or transaction payload path was added.
