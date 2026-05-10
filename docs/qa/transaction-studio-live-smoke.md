# Transaction Studio Live Smoke

Transaction Studio T2 live smoke uses only public data and read-only RPC methods. It must never use private keys, seed phrases, wallet JSON, signing seeds, `sendTransaction`, `requestAirdrop`, broadcast endpoints, bundles, or arbitrary RPC.

## Safe Inputs

Committed safe fixtures:

- Valid public address: `11111111111111111111111111111111`
- Invalid signature: `not-a-solana-signature`
- Invalid address: `not-a-solana-address`

Optional public signatures should be selected from a public explorer or internal QA notes immediately before the smoke run. Do not use user-sensitive signatures. Use:

- `GORKH_TX_STUDIO_SMOKE_SIGNATURE` for a generic public Solana transaction.
- `GORKH_TX_STUDIO_SPL_SIGNATURE` for a public SPL token transfer.
- `GORKH_TX_STUDIO_JUPITER_SIGNATURE` for a public Jupiter route.
- `GORKH_TX_STUDIO_FAILED_SIGNATURE` for a public failed transaction.
- `GORKH_TX_STUDIO_RAW_TX_BASE64` for a static test-safe raw transaction fixture.

These values are local environment variables only and must not be committed.

## Script

Run:

```sh
scripts/transaction-studio-smoke.sh
```

Optional network:

```sh
GORKH_TX_STUDIO_RPC_URL=https://api.mainnet-beta.solana.com \
GORKH_TX_STUDIO_SMOKE_SIGNATURE=<public_signature> \
scripts/transaction-studio-smoke.sh --live
```

The script performs:

- local invalid input checks,
- read-only account fetch with `getParsedAccountInfo`,
- optional read-only `getTransaction` for public signatures,
- optional read-only `simulateTransaction` for `GORKH_TX_STUDIO_RAW_TX_BASE64`.

## Expected Results

### Public Address

- `getParsedAccountInfo` returns account summary or null.
- No signing or execution path appears.

### Public Signature

- `getTransaction` returns transaction data or an honest unavailable state.
- Studio should decode programs, signers, writable accounts, and parser-supported instructions.

### SPL Token Transfer Signature

- SPL Token or Token-2022 program is labeled.
- Transfer/TransferChecked parser shows source, destination, authority, raw amount, and mint/decimals when available.

### Jupiter Signature

- Jupiter program is labeled as a route.
- Deep route internals remain opaque unless confidently parsed.
- Risk review includes DeFi aggregator route context.

### Failed Transaction Signature

- Fetch may succeed while simulation may be unavailable or fail.
- UI should show failure/unavailable state honestly.

### Raw Transaction Fixture

- Decode runs locally.
- Simulation is attempted only through `simulateTransaction`.
- No raw transaction is stored in history by default.

## Evidence to Record

- Date/time of smoke.
- RPC host used.
- Which optional signature slots were populated.
- Decode status.
- Simulation status.
- Highest risk level.
- Any unavailable/error reason.

Do not record API keys, private keys, wallet files, raw transaction payloads, or screenshots containing sensitive data.
