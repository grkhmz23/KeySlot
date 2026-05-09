# GORKH Meteora Read-Only Helper

This helper is a public-data-only boundary for Meteora DLMM LP position tracking.

Allowed commands:

- `health`
- `env-check`
- `positions`

Allowed inputs:

- public wallet address
- network
- optional RPC URL
- request ID

Forbidden inputs:

- private keys
- secret keys
- seed phrases
- mnemonics
- wallet JSON
- signing seed bytes
- transaction payloads
- instruction payloads

The helper uses the official Meteora DLMM SDK read-only function:

- `DLMM.getAllLbPairPositionsByUser(connection, userPublicKey)`

It must not call liquidity action, fee claim, close-position, swap, signing, or transaction-builder methods.

Run tests:

```bash
npm test
```

Run a read-only smoke:

```bash
npm run smoke -- --expected empty
```

Or from the repository root:

```bash
scripts/meteora-readonly-smoke.sh --expected empty
```
