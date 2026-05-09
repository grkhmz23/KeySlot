# Lending Dashboard Smoke Checklist

Phase 3.4 is read-only. Do not run lending transactions.

## Manual UI Smoke

1. Open Wallet -> Portfolio.
2. Refresh Portfolio for active wallet, all wallets, local wallets, and watch-only wallets.
3. Confirm the Lending panel appears below Stake/LST intelligence.
4. Confirm Kamino and MarginFi protocol cards show `Unavailable` until reviewed read-only adapters are connected.
5. Confirm Deposit, Borrow, Repay, and Withdraw actions are disabled/locked.
6. Confirm the copy says lending values are separate from wallet token balances to avoid double-counting.
7. Confirm Portfolio total value does not include lending net value.
8. Confirm Snapshot History includes the lending position count.
9. Confirm Audit shows lending refresh/unavailable and snapshot events without secrets.

## Safety Checks

Run:

```bash
rg -n "mnemonic|seed phrase|privateKey|secretKey|wallet JSON|signingSeed|transactionPayload|serializedTransaction" apps/macos/GORKH/GORKH docs
```

Expected:

- No lending dashboard code stores or logs secrets.
- No lending dashboard code builds transactions.
- Words such as deposit, borrow, repay, and withdraw appear only as locked labels, docs, tests, or forbidden execution copy.
