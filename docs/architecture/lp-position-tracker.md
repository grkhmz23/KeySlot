# LP Position Tracker

Phase 3.5 adds read-only LP position intelligence inside Wallet -> Portfolio. Meteora was first because the official DLMM TypeScript SDK exposes a public read-only user-position method:

- `DLMM.getAllLbPairPositionsByUser(connection, userPublicKey)`

Phase 3.5B adds Orca Whirlpools through the official TypeScript SDK read-only owner lookup:

- `fetchPositionsForOwner(rpc, owner)`

Official docs reviewed:

- Meteora DLMM TypeScript SDK functions: `https://docs.meteora.ag/developer-guide/guides/dlmm/typescript-sdk/sdk-functions`
- Meteora DLMM concepts: `https://docs.meteora.ag/overview/products/dlmm/dlmm-concepts`
- Orca Whirlpools TypeScript SDK `fetchPositionsForOwner`: `https://dev.orca.so/ts/functions/_orca-so_whirlpools.fetchPositionsForOwner.html`
- Orca public API base: `https://api.orca.so/v2/solana`

## Scope

- Portfolio Liquidity panel with protocol cards for Meteora, Orca, and Raydium.
- Meteora helper boundary under `tools/meteora-readonly/`.
- Orca helper boundary under `tools/orca-readonly/`.
- Safe LP models for pool address, position address, token mints, optional amounts, optional fees, bin/range state, value state, source, timestamp, and adapter status.
- Portfolio snapshots store LP counts, protocol statuses, partial/unavailable counts, and optional estimated value only.
- LP values are shown separately from wallet token balances to avoid double-counting.

## Execution Boundary

The LP tracker does not request signing, does not build transactions, and does not call transaction builders. Add liquidity, remove liquidity, fee claim, and close position actions are locked in UI.

No private keys, seed phrases, mnemonics, signing seeds, wallet JSON, serialized transactions, instruction payloads, or raw signer data are accepted by the helper, stored in snapshots, logged, or audited.

## Meteora Helper

Helper path:

- `tools/meteora-readonly/src/index.ts`

Commands:

- `health`
- `env-check`
- `positions`

Inputs:

- public wallet address
- mainnet-beta network
- optional RPC URL
- request ID

Dependency pins:

- `@meteora-ag/dlmm@1.7.5`
- `@solana/web3.js@1.98.4`

Dependency audit notes are tracked in `docs/security/meteora-readonly-dependency-audit.md`.

The helper imports the official SDK and calls only:

- `DLMM.getAllLbPairPositionsByUser`

Forbidden SDK/action methods are denylisted and tested:

- `addLiquidity`
- `removeLiquidity`
- `claimFee`
- `claimFees`
- `closePosition`
- `createPosition`
- `initializePosition`
- `initializePositionAndAddLiquidityByStrategy`
- `swap`
- `sendTransaction`
- `signTransaction`
- `buildTransaction`
- `createTransaction`
- `removeLiquidityByRange`
- `claimAllSwapFee`
- `claimLMReward`

The native Swift bridge is fixed-path and disabled by default. If enabled for development, it invokes only the fixed helper path with the allowlisted command set and JSON stdin/stdout. No shell string execution and no process environment passthrough are used.

## Orca Helper

Helper path:

- `tools/orca-readonly/src/index.ts`

Commands:

- `health`
- `env-check`
- `positions`

Inputs:

- public wallet address
- mainnet-beta network
- optional RPC URL
- request ID

Dependency pins:

- `@orca-so/whirlpools@7.0.2`
- `@solana/kit@5.5.1`

Reviewed public constants:

- Whirlpool Program ID: `whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc`
- Mainnet WhirlpoolConfig: `2LecshUwdy9xi7meFgHtFJQNSKk4KdTrcpvaB56dP2NQ`
- Devnet WhirlpoolConfig: `FcrweFY1G9HJAHG5inkGB6pKg1HZ6x9UC2WioAfWrGkR`
- Public API base: `https://api.orca.so/v2/solana`

The helper imports the official Orca Whirlpools SDK and Solana Kit, sets the mainnet Whirlpools config, creates a read-only RPC client, and calls only:

- `fetchPositionsForOwner`

The public API is no-auth read access and may be used later only for metadata or pool enrichment through read-only endpoints such as `/pools`, `/pools/search`, `/pools/{address}`, `/protocol`, and `/tokens/{mint_address}`. It must not replace on-chain ownership discovery.

Forbidden SDK/action methods are denylisted and tested:

- `increaseLiquidity`
- `decreaseLiquidity`
- `collectFees`
- `collectRewards`
- `updateFeesAndRewards`
- `harvestPosition`
- `closePosition`
- `openPosition`
- `createPosition`
- `openFullRangePosition`
- `createSplashPool`
- `createConcentratedLiquidityPool`
- `swap`
- `transactionBuilder`
- `buildTransaction`
- `buildAndSendTransaction`
- `sendTransaction`
- `signTransaction`
- `tx-sender`
- `setDefaultFunder`
- `setPayerFromBytes`

The native Swift bridge follows the same fixed-path policy as Meteora. It is disabled by default in normal app construction and can be injected for development/testing. It accepts only safe JSON summaries and rejects helper output containing sensitive or transaction payload fields.

## Adapter Status

Meteora:

- `loaded` when positions include enough token/range data to show a complete read-only position summary.
- `empty` when the official SDK returns no positions for a public wallet.
- `partial` when positions are found but token amounts, fees, value, or range metadata are incomplete.
- `unavailable` when the helper is disabled, missing, unsupported, or SDK import/method availability fails.
- `error` when the read-only lookup fails.

Orca:

- `loaded` when the helper returns Whirlpools positions with pool, token, and tick metadata.
- `empty` when the official SDK returns no positions for a public wallet.
- `partial` when positions are found but token amounts, fees, value, or tick/range metadata are incomplete.
- `unavailable` when the helper is disabled, missing, unsupported, lacks an RPC URL, or SDK import/method availability fails.
- `error` when the read-only lookup fails.

Raydium:

- Placeholder only. It returns `unavailable` with an explicit reason.
- No data is faked.
- No SDK or action path is imported.

## Storage and Audit

Snapshots may store:

- LP position count
- protocol statuses
- partial and unavailable counts
- optional estimated LP value
- timestamp

Snapshots and audit must not store raw SDK responses, raw position payloads, private material, instruction payloads, or transaction data.

## Future Requirements

Future Raydium or richer Meteora/Orca valuation work must prove:

- read-only wallet/public-address lookup only,
- no action builders or transaction builders,
- no signing methods,
- bounded RPC/API calls,
- honest empty/partial/unavailable states,
- no double-counting against wallet token balances,
- tests that fail on forbidden method names outside denylist/tests/docs.
