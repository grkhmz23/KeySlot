# Lending Dashboard Smoke Checklist

Phase 3.4D is read-only. Do not run lending transactions.

## Manual UI Smoke

1. Open Wallet -> Portfolio.
2. Refresh Portfolio for active wallet, all wallets, local wallets, and watch-only wallets.
3. Confirm the Lending panel appears below Stake/LST intelligence.
4. On mainnet-beta, confirm Kamino shows public API market context or wallet positions/empty state from read-only public endpoints.
5. Confirm MarginFi shows `Empty`, `Partial`, `Unavailable`, or `Error` honestly. If accounts are found, confirm `Partial` explains that asset metadata/value/health parsing is unavailable.
6. Confirm Deposit, Borrow, Repay, and Withdraw actions are disabled/locked.
7. Confirm the copy says lending values are separate from wallet token balances to avoid double-counting.
8. Confirm Portfolio total value does not include lending net value.
9. Confirm Snapshot History includes the lending position count, market count, and safe adapter status summary.
10. Confirm Audit shows lending refresh/unavailable and snapshot events without secrets.

## Kamino Read-Only Endpoints

Allowed:

- `https://api.kamino.finance/v2/kamino-market`
- `https://api.kamino.finance/kamino-market/{marketPubkey}/reserves/metrics?env=mainnet-beta`
- `https://api.kamino.finance/kamino-market/{marketPubkey}/users/{userPubkey}/obligations?env=mainnet-beta`

Blocked by guard:

- any transaction, unsigned transaction, action, instruction, deposit, borrow, repay, withdraw, liquidate, leverage, multiply, swap, or order endpoint path.

## MarginFi On-Chain Read-Only Parser

Official docs reviewed:

- `https://docs.marginfi.com/`
- `https://docs.marginfi.com/ts-sdk`
- `https://docs.marginfi.com/mfi-v2`
- Official `mrgnlabs/marginfi-v2` source for account discriminators, zero-copy account size, authority offset, and balance-slot layout.

Configured program metadata:

- marginfi v2 mainnet-beta program: `MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA`
- marginfi v2 main group: `4qp6Fx6tnZkY5Wropq9wUYgtFxXKwE6viZxFHg3rdAG8`

Allowed MarginFi read-only RPC:

- `getAccountInfo` for the official program account status check.
- `getProgramAccounts` with data-size and authority memcmp filters for bounded account discovery.

Blocked by guard:

- any HTTP path or RPC method containing transaction, unsigned transaction, action, instruction, create, account-create, deposit, borrow, repay, withdraw, liquidate, leverage, multiply, loop, swap, or order.

Expected state:

- MarginFi program status can be checked on mainnet-beta.
- MarginFi account discovery is bounded by official account size and authority offset.
- Parsed account fields are discriminator, group, authority, flags, active balance bank references, side, tag, and last update.
- Bank token metadata, share-to-token amount conversion, USD value, LTV, and health remain unavailable until a bank/oracle parser is audited.
- If no MarginFi accounts are found for the wallet, the adapter returns `Empty`.
- If accounts are found but values/health cannot be computed, the adapter returns `Partial`.
- No account creation, lending action, SDK action builder, signer, or transaction path is used.

## Safety Checks

Run:

```bash
rg -n "mnemonic|seed phrase|privateKey|secretKey|wallet JSON|signingSeed|transactionPayload|serializedTransaction" apps/macos/GORKH/GORKH docs
```

Expected:

- No lending dashboard code stores or logs secrets.
- No lending dashboard code builds transactions.
- Words such as deposit, borrow, repay, withdraw, liquidate, create, and leverage appear only as locked labels, docs, tests, denylist entries, or forbidden execution copy.
