# LP Position Tracker Smoke Checklist

Phase 3.5 is read-only. Do not run LP transactions.

## Manual UI Smoke

1. Open Wallet -> Portfolio.
2. Refresh Portfolio for active wallet, all wallets, local wallets, and watch-only wallets.
3. Confirm the Liquidity panel appears below Lending.
4. Confirm the panel says read-only and execution locked.
5. Confirm Meteora shows `Loaded`, `Empty`, `Partial`, `Unavailable`, or `Error` honestly.
6. Confirm Orca and Raydium show unavailable placeholders.
7. Confirm Add liquidity, Remove liquidity, Claim fees, and Close position controls are disabled.
8. Confirm the copy says LP values are separate from wallet token balances to avoid double-counting.
9. Confirm Portfolio total value does not include LP value.
10. Confirm Snapshot History includes LP position count.
11. Confirm Audit shows LP refresh/snapshot events without secrets.

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

## Expected States

- `Loaded`: positions are returned with enough token and range data to display a complete read-only summary.
- `Empty`: the public wallet has no returned Meteora DLMM positions.
- `Partial`: positions are found but amounts, value, fees, or range data are incomplete.
- `Unavailable`: helper, SDK import, RPC URL, or network is unavailable.
- `Error`: read-only lookup failed.

## Safety Checks

Run:

```bash
rg -n "mnemonic|seed phrase|privateKey|secretKey|wallet JSON|signingSeed|transactionPayload|serializedTransaction|unsignedTransaction|instruction" apps/macos/GORKH/GORKH docs tools/meteora-readonly
```

Expected:

- No LP code stores or logs secrets.
- No LP code builds transactions.
- Words for LP actions appear only as locked labels, docs, tests, denylist entries, or forbidden execution copy.
