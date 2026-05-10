# Transaction Studio Public Fixtures

Use only public signatures and public addresses for Transaction Studio smoke. Do not commit user-sensitive signatures, private keys, seed phrases, wallet files, API keys, raw transaction payloads, or screenshots containing secrets.

## Fixture Slots

Populate these locally when running live smoke:

- `GORKH_TX_STUDIO_SMOKE_SIGNATURE`: public generic Solana transaction signature.
- `GORKH_TX_STUDIO_SPL_SIGNATURE`: public SPL token transfer signature.
- `GORKH_TX_STUDIO_JUPITER_SIGNATURE`: public Jupiter route signature.
- `GORKH_TX_STUDIO_FAILED_SIGNATURE`: public failed transaction signature.
- `GORKH_TX_STUDIO_ALT_SIGNATURE`: public v0 transaction using address lookup tables.
- `GORKH_TX_STUDIO_SMOKE_ADDRESS`: public address fixture.
- `GORKH_TX_STUDIO_SMOKE_RPC_URL`: read-only Solana RPC URL.
- `GORKH_TX_STUDIO_RAW_TX_BASE64`: optional static test-safe raw transaction for simulation.

The committed default address fixture is the System Program:

```text
11111111111111111111111111111111
```

## Selection Rules

- Prefer transactions from public explorers or protocol docs.
- Do not use private customer or user wallet activity.
- Do not use signatures that reveal unreleased internal testing.
- Do not paste private material into shell history.
- Do not commit local `.env` files.

## Live Smoke Command

```sh
GORKH_TX_STUDIO_SMOKE_RPC_URL=https://api.mainnet-beta.solana.com \
GORKH_TX_STUDIO_SMOKE_ADDRESS=11111111111111111111111111111111 \
GORKH_TX_STUDIO_ALT_SIGNATURE=<public_v0_alt_signature> \
scripts/transaction-studio-smoke.sh --live
```

You can also pass one-off public fixtures without exporting env:

```sh
scripts/transaction-studio-smoke.sh --live --address 11111111111111111111111111111111 --signature <public_signature>
```

The script uses only `getParsedAccountInfo`, `getTransaction`, and optional `simulateTransaction` for a static fixture. It must not use signing, broadcasting, `requestAirdrop`, bundles, or arbitrary RPC methods.
