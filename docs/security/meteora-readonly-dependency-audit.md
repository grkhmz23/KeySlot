# Meteora Read-Only Helper Dependency Audit

Date: 2026-05-09

Command:

```bash
cd tools/meteora-readonly
npm audit --json
```

## Direct Dependencies

- `@meteora-ag/dlmm@1.7.5`
- `@solana/web3.js@1.98.4`

Both direct dependencies are exact-pinned in `package.json` and locked in `package-lock.json`.

## Audit Summary

`npm audit --json` reports 4 high-severity findings:

- `@meteora-ag/dlmm` via transitive `@solana/spl-token`
- `@solana/spl-token` via transitive `@solana/buffer-layout-utils`
- `@solana/buffer-layout-utils` via transitive `bigint-buffer`
- `bigint-buffer` advisory `GHSA-3gc7-fjrx-p6mg`

No automatic fix is available from npm for this dependency graph.

## Runtime Impact Review

The helper is read-only and calls only `DLMM.getAllLbPairPositionsByUser(connection, userPublicKey)`. It does not accept private keys, signing seeds, wallet JSON, transaction payloads, or instruction payloads. It does not call liquidity action methods, signing methods, transaction builders, or Solana send APIs.

The reported vulnerability is still tracked as a helper dependency risk because the official Meteora SDK pulls the affected transitive package. GORKH should revisit this when Meteora publishes a dependency update or a newer SDK version that removes the vulnerable transitive chain.

## Mitigation

- Keep helper command set limited to `health`, `env-check`, and `positions`.
- Keep source guards that fail tests if forbidden action methods are called.
- Keep Swift native helper invocation disabled by default.
- Do not run automatic audit fixes unless the SDK compatibility and smoke tests are reviewed again.
