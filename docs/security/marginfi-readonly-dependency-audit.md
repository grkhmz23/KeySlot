# MarginFi Read-Only Dependency Audit

Date: 2026-05-09

Scope: `tools/marginfi-readonly`

This helper is read-only. It accepts public wallet addresses and RPC URLs only. It does not receive wallet private keys, seed phrases, signing seed bytes, wallet JSON, serialized transactions, or instruction payloads.

## Direct Dependencies

`npm ls --depth=0`:

- `@mrgnlabs/marginfi-client-v2@4.0.4`
- `@mrgnlabs/mrgn-common@2.0.7`
- `@solana/web3.js@1.98.4`
- `debug@4.4.1`

Direct dependency versions are pinned exactly in `package.json`, and `package-lock.json` is committed.

`debug@4.4.1` is included because `@mrgnlabs/marginfi-client-v2@4.0.4` imports `debug` at runtime but does not list it as a runtime dependency. It is not used for GORKH logging.

## Audit Result

Command:

```bash
cd tools/marginfi-readonly
npm audit --json
```

Result:

- Total vulnerabilities: 7
- High severity: 7
- Critical severity: 0

Reported packages:

- `@mrgnlabs/mrgn-common` (direct): high, via `@solana/buffer-layout-utils` and nested `@solana/web3.js`.
- `@solana/buffer-layout-utils` (transitive): high, via `bigint-buffer`.
- nested `@solana/web3.js` (transitive under `@mrgnlabs/mrgn-common` and `jito-ts`): high, via `bigint-buffer`, affected range `1.43.1 - 1.98.0`.
- `bigint-buffer` (transitive): high, advisory `GHSA-3gc7-fjrx-p6mg`, buffer overflow in `toBigIntLE()`, range `<=1.1.5`.
- `jito-ts` (transitive): high, via nested `@solana/web3.js`.
- `@pythnetwork/solana-utils` (transitive): high, via `jito-ts`.
- `@pythnetwork/pyth-solana-receiver` (transitive): high, via `@pythnetwork/solana-utils`.

## Runtime Exposure Notes

The helper is still isolated and read-only:

- No signing methods are available; the wallet stub throws on `signTransaction`, `signAllTransactions`, and `signMessage`.
- No MarginFi action methods are called.
- No transaction builders are called.
- No raw transaction or instruction payloads are accepted or emitted.
- Smoke output is a safe summary only.

The audit findings are still relevant because the helper imports the official SDK and its transitive parsing/RPC dependencies at runtime. The current mitigation is isolation, no secrets, no signing, pinned versions, source guards, and read-only smoke coverage.

## Why No Automatic Fix Was Applied

`npm audit fix` was not applied. The report suggests dependency changes involving `@mrgnlabs/mrgn-common` and transitive Solana/Pyth/Jito packages. Those changes may downgrade or alter SDK compatibility and must be reviewed against MarginFi SDK behavior before adoption.

## Recommended Mitigation

- Monitor `@mrgnlabs/marginfi-client-v2` and `@mrgnlabs/mrgn-common` releases for a dependency tree that removes affected nested `@solana/web3.js` and `bigint-buffer` versions.
- Re-run `npm audit --json`, helper tests, and `scripts/marginfi-readonly-smoke.sh` after any dependency change.
- Keep the helper disabled or development-gated for broad production distribution until the dependency tree is remediated or formally accepted.
- Do not introduce lending execution until the read-only dependency risk is resolved or explicitly accepted with a stronger sandbox.
