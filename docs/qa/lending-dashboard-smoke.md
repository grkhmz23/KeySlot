# Lending Dashboard Smoke Checklist

Phase 3.4B is read-only. Do not run lending transactions.

## Manual UI Smoke

1. Open Wallet -> Portfolio.
2. Refresh Portfolio for active wallet, all wallets, local wallets, and watch-only wallets.
3. Confirm the Lending panel appears below Stake/LST intelligence.
4. On mainnet-beta, confirm Kamino shows public API market context or wallet positions/empty state from read-only public endpoints.
5. Confirm MarginFi still shows `Unavailable` until a reviewed read-only adapter is connected.
6. Confirm Deposit, Borrow, Repay, and Withdraw actions are disabled/locked.
7. Confirm the copy says lending values are separate from wallet token balances to avoid double-counting.
8. Confirm Portfolio total value does not include lending net value.
9. Confirm Snapshot History includes the lending position count and market count.
10. Confirm Audit shows lending refresh/unavailable and snapshot events without secrets.

## Kamino Read-Only Endpoints

Allowed:

- `https://api.kamino.finance/v2/kamino-market`
- `https://api.kamino.finance/kamino-market/{marketPubkey}/reserves/metrics?env=mainnet-beta`
- `https://api.kamino.finance/kamino-market/{marketPubkey}/users/{userPubkey}/obligations?env=mainnet-beta`

Blocked by guard:

- any transaction, unsigned transaction, action, instruction, deposit, borrow, repay, withdraw, liquidate, leverage, multiply, swap, or order endpoint path.

## Safety Checks

Run:

```bash
rg -n "mnemonic|seed phrase|privateKey|secretKey|wallet JSON|signingSeed|transactionPayload|serializedTransaction" apps/macos/GORKH/GORKH docs
```

Expected:

- No lending dashboard code stores or logs secrets.
- No lending dashboard code builds transactions.
- Words such as deposit, borrow, repay, withdraw, and liquidate appear only as locked labels, docs, tests, denylist entries, or forbidden execution copy.
