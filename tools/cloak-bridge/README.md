# GORKH Cloak Bridge Scaffold

This helper is a locked contract scaffold for future `@cloak.dev/sdk` integration.

Phase 2.2 supports only:

- `health`
- `env-check`
- `deposit-plan`

It does not execute:

- `transact`
- `fullWithdraw`
- `partialWithdraw`
- private transfer
- swap
- scan
- compliance export

Requests are JSON over stdin and responses are JSON on stdout. The helper rejects forbidden fields such as wallet private keys, seed phrases, mnemonics, wallet JSON, UTXO private keys, notes, viewing keys, nullifiers, proof inputs, serialized transactions, transaction payloads, or raw signer bytes.

Examples:

```bash
npm run health
printf '{"network":"mainnet-beta"}' | npm run env-check
printf '{"amountLamports":"50000000","walletPublicAddress":"11111111111111111111111111111111"}' | npm run deposit-plan
```

The bridge returns fee quotes and locked status only. It must not receive real wallet secrets.
