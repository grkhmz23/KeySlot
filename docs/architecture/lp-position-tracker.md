# LP Position Tracker

Phase 3.5 adds read-only LP position intelligence inside Wallet -> Portfolio. Meteora was first because the official DLMM TypeScript SDK exposes a public read-only user-position method:

- `DLMM.getAllLbPairPositionsByUser(connection, userPublicKey)`

Phase 3.5B first added Orca Whirlpools through the official TypeScript SDK read-only owner lookup:

- `fetchPositionsForOwner(rpc, owner)`

Orca LP Manager v1 extends the same helper boundary with one approved execution path:

- `harvestPositionInstructions(rpc, positionMint, authority)`

The helper builds unsigned harvest instruction proposals only. It does not sign, send, use tx-sender, use Jito tips, read wallet files, call SDK callback send paths, or receive wallet secret material.

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
- Orca harvest plan/review/simulation/approval/sign/send flow for existing Orca positions only.
- Portfolio snapshots store LP counts, protocol statuses, partial/unavailable counts, and optional estimated value only.
- LP values are shown separately from wallet token balances to avoid double-counting.

## Execution Boundary

Meteora and Raydium remain read-only. Orca supports one execution action: harvest fees/rewards for an already owned LP position.

Orca harvest follows the same wallet safety pipeline as other real wallet actions:

1. position discovered for selected wallet,
2. harvest plan built by helper as unsigned instruction metadata,
3. Swift message construction and local review,
4. simulation,
5. explicit approval,
6. wallet unlock and LocalAuthentication,
7. native signing,
8. send through GORKH RPC,
9. confirmation,
10. audit.

Add liquidity, remove liquidity, open position, close position, and swap actions are locked in UI.

No private keys, seed phrases, mnemonics, signing seeds, wallet JSON, serialized transactions, instruction payloads, or raw signer data are accepted by the helper, stored in snapshots, logged, or audited.

## Meteora Helper

Helper path:

- `tools/meteora-readonly/src/index.ts`

Commands:

- `health`
- `env-check`
- `positions`
- `harvest-plan`

Read-only position inputs:

- public wallet address
- mainnet-beta network
- optional RPC URL
- request ID

Harvest plan inputs:

- public wallet address
- position mint
- optional position address
- mainnet-beta network
- RPC URL
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

The helper imports the official Orca Whirlpools SDK and Solana Kit, sets the mainnet Whirlpools config, creates an RPC client, and calls only:

- `fetchPositionsForOwner`
- `harvestPositionInstructions`

The harvest authority is a public-key-only object. Its signing method throws, and helper tests verify it cannot sign. Swift native signing remains the only signing path.

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
- `wallet.json`
- `ANCHOR_WALLET`
- `tx-sender`
- `buildAndSendTransaction`
- `callback(`
- `sendTx(`

The native Swift bridge follows the same fixed-path policy as Meteora. It accepts only safe JSON summaries and harvest instruction proposals from the allowlisted helper command. It rejects helper output containing sensitive fields or user-supplied transaction payload fields.

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
- Harvest action is available only for Orca positions with a position mint and only after a plan can be built for the selected wallet.

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
