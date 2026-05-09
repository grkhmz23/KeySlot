# LP Position Tracker Smoke Checklist

Phase 3.5 is read-only. Do not run LP transactions.

## Manual UI Smoke

1. Open Wallet -> Portfolio.
2. Refresh Portfolio for active wallet, all wallets, local wallets, and watch-only wallets.
3. Confirm the Liquidity panel appears below Lending.
4. Confirm the panel says read-only and execution locked.
5. Confirm Meteora shows `Loaded`, `Empty`, `Partial`, `Unavailable`, or `Error` honestly.
6. Confirm Orca shows `Loaded`, `Empty`, `Partial`, `Unavailable`, or `Error` honestly.
7. Confirm Raydium shows an unavailable placeholder.
8. Confirm Add liquidity, Remove liquidity, Claim fees, and Close position controls are disabled.
9. Confirm the copy says LP values are separate from wallet token balances to avoid double-counting.
10. Confirm Portfolio total value does not include LP value.
11. Confirm Snapshot History includes LP position count.
12. Confirm Audit shows LP refresh/snapshot events without secrets.

## Meteora Helper

Official read-only SDK method:

- `DLMM.getAllLbPairPositionsByUser(connection, userPublicKey)`

Helper boundary:

- path: `tools/meteora-readonly/src/index.ts`
- commands: `health`, `env-check`, `positions`
- smoke wrapper: `scripts/meteora-readonly-smoke.sh`
- dependencies: `@meteora-ag/dlmm@1.7.5`, `@solana/web3.js@1.98.4`
- input: public wallet address, network, optional RPC URL, request ID
- forbidden input: private key, seed phrase, mnemonic, signing seed, wallet JSON, serialized transaction, instruction payload

Run helper tests:

```bash
cd tools/meteora-readonly
npm test
```

Run read-only smoke against the default public empty wallet:

```bash
scripts/meteora-readonly-smoke.sh --expected empty
```

Run read-only smoke against a known public Meteora LP wallet:

```bash
GORKH_METEORA_SMOKE_WALLET=<public-wallet> scripts/meteora-readonly-smoke.sh
```

The smoke prints only a safe summary: wallet public address, status, SDK version, redacted RPC status, position count, and partial/unavailable reason. It must not print private keys, seed phrases, wallet JSON, raw SDK dumps, transaction payloads, or instruction payloads.

Dependency audit details for the helper live in `docs/security/meteora-readonly-dependency-audit.md`.

## Orca Helper

Official read-only SDK method:

- `fetchPositionsForOwner(rpc, owner)`

Official docs reviewed:

- `https://dev.orca.so/ts/functions/_orca-so_whirlpools.fetchPositionsForOwner.html`

Reviewed public constants:

- Whirlpool Program ID: `whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc`
- Mainnet WhirlpoolConfig: `2LecshUwdy9xi7meFgHtFJQNSKk4KdTrcpvaB56dP2NQ`
- Devnet WhirlpoolConfig: `FcrweFY1G9HJAHG5inkGB6pKg1HZ6x9UC2WioAfWrGkR`
- Public API base: `https://api.orca.so/v2/solana`

The public API is no-auth read access and can enrich pool/token metadata only. Position ownership discovery must remain on-chain through `fetchPositionsForOwner`.

Helper boundary:

- path: `tools/orca-readonly/src/index.ts`
- commands: `health`, `env-check`, `positions`
- smoke wrapper: `scripts/orca-readonly-smoke.sh`
- dependencies: `@orca-so/whirlpools@7.0.2`, `@solana/kit@5.5.1`
- input: public wallet address, network, optional RPC URL, request ID
- forbidden input: private key, seed phrase, mnemonic, signing seed, wallet JSON, serialized transaction, instruction payload

Run helper tests:

```bash
cd tools/orca-readonly
npm test
```

Run read-only smoke with no RPC URL to verify the unavailable state is safe:

```bash
scripts/orca-readonly-smoke.sh --expect unavailable
```

Run read-only smoke against a known public Orca Whirlpools wallet:

```bash
GORKH_ORCA_SMOKE_WALLET=<public-wallet> SOLANA_RPC_URL=<read-only-rpc-url> scripts/orca-readonly-smoke.sh
```

The smoke prints only a safe summary: wallet public address, status, SDK versions, position count, and partial/unavailable reason. It must not print private keys, seed phrases, wallet JSON, raw SDK dumps, transaction payloads, or instruction payloads.

Do not use Orca tx-sender, Jito tips, private-key/file-wallet loading, or any callback that sends a transaction in this helper.

## Expected States

- `Loaded`: positions are returned with enough token and range data to display a complete read-only summary.
- `Empty`: the public wallet has no returned positions for that adapter.
- `Partial`: positions are found but amounts, value, fees, or range data are incomplete.
- `Unavailable`: helper, SDK import, RPC URL, or network is unavailable.
- `Error`: read-only lookup failed.

## Safety Checks

Run:

```bash
rg -n "mnemonic|seed phrase|privateKey|secretKey|wallet JSON|signingSeed|transactionPayload|serializedTransaction|unsignedTransaction|instruction" apps/macos/GORKH/GORKH docs tools/meteora-readonly tools/orca-readonly
```

Expected:

- No LP code stores or logs secrets.
- No LP code builds transactions.
- Words for LP actions appear only as locked labels, docs, tests, denylist entries, or forbidden execution copy.
