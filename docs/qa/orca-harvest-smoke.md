# Orca Harvest Smoke Checklist

This smoke is for Orca Whirlpools harvest fees/rewards only. It must not open positions, add liquidity, remove liquidity, close positions, swap, use tx-sender, use Jito tips, or load wallet files.

Do not run a mainnet harvest automatically. Use the desktop app approval flow only, with a wallet you control and an LP position that can safely harvest a small amount.

## Preconditions

- Mainnet RPC is configured through GORKH RPC.
- The selected wallet is a local signer wallet, not watch-only.
- The selected wallet owns an Orca LP position mint.
- Wallet has enough SOL for fees and any required token account rent.
- User is ready to type the exact mainnet confirmation phrase.

## Helper Tests

Run:

```bash
cd tools/orca-readonly
npm test
```

Expected:

- `positions` returns safe read-only summaries.
- `harvest-plan` returns only unsigned instruction metadata.
- forbidden input fields are rejected.
- the public-key-only authority cannot sign.
- tx-sender, wallet file loading, callback send paths, and transaction send helpers are not used.

## Read-Only Position Smoke

Run with unavailable-safe defaults:

```bash
scripts/orca-readonly-smoke.sh --expect unavailable
```

Run against a known public Orca LP wallet:

```bash
GORKH_ORCA_SMOKE_WALLET=<public-wallet> SOLANA_RPC_URL=<read-only-rpc-url> scripts/orca-readonly-smoke.sh
```

Expected output is a safe summary only:

- status
- wallet public address
- SDK version
- position count
- partial or unavailable reason

It must not print private keys, seed phrases, wallet JSON, raw SDK dumps, signed transactions, or instruction payload dumps.

## Desktop Harvest Smoke

1. Open Wallet -> Portfolio -> Liquidity.
2. Refresh the portfolio.
3. Confirm Orca shows `Loaded`, `Empty`, `Partial`, `Unavailable`, or `Error` honestly.
4. Select an Orca LP position owned by the active signer wallet.
5. Click `Harvest fees/rewards`.
6. Confirm the approval panel shows wallet, position mint, pool, instruction count, writable account count, and mainnet warning.
7. Click `Simulate harvest`.
8. If simulation fails, confirm approval remains blocked and the error is shown.
9. If simulation succeeds, type the exact mainnet confirmation phrase.
10. Confirm LocalAuthentication is requested.
11. Confirm the transaction is signed by the native wallet signer and submitted through GORKH RPC.
12. Confirm the signature is shown after send.
13. Confirm Audit records plan, simulation, approval, send, or failure events without secrets.

Do not continue if:

- the helper asks for a private key, seed phrase, wallet file, or signer callback,
- the app skips simulation,
- the approval panel is missing,
- LocalAuthentication is skipped,
- the position is not owned by the selected wallet,
- add/remove/open/close controls become active.

## Locked Actions

These must remain locked:

- open position
- add liquidity
- remove liquidity
- close position
- swap

The UI should describe Orca ownership records as LP positions, position tokens, or position mints only.
