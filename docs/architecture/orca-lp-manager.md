# Orca LP Manager

Phase 3.5B adds real Orca Whirlpools harvest execution for existing LP positions inside Wallet -> Portfolio -> Liquidity.

This is intentionally narrow execution support:

- Read LP positions with the official Orca Whirlpools TypeScript SDK.
- Build a harvest fees/rewards instruction proposal for an existing position mint.
- Decode and review the proposal in Swift.
- Simulate before approval.
- Require explicit approval, mainnet confirmation, wallet unlock, and LocalAuthentication.
- Sign only with the native GORKH signer.
- Send only through the existing Solana RPC client.
- Audit every plan, simulation, approval, send, failure, and guard block.

Opening positions, adding liquidity, removing liquidity, closing positions, swaps, tx-sender, Jito tips, and helper-side signing remain out of scope.

## Official Orca Inputs

Reviewed Orca facts:

- Public API base: `https://api.orca.so/v2/solana`
- Whirlpool Program ID: `whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc`
- Mainnet WhirlpoolConfig: `2LecshUwdy9xi7meFgHtFJQNSKk4KdTrcpvaB56dP2NQ`
- Devnet WhirlpoolConfig: `FcrweFY1G9HJAHG5inkGB6pKg1HZ6x9UC2WioAfWrGkR`
- Read-only discovery: `fetchPositionsForOwner(rpc, owner)`
- Harvest planning: `harvestPositionInstructions(rpc, positionMint, authority)`

The helper uses the public API only as future metadata enrichment. Position ownership discovery stays on-chain through the SDK owner lookup.

## Helper Boundary

Helper path:

- `tools/orca-readonly/src/index.ts`

Commands:

- `health`
- `env-check`
- `positions`
- `harvest-plan`

Allowed inputs:

- wallet public address
- position mint
- optional position address
- network
- RPC URL
- request ID

Forbidden inputs:

- private key
- secret key
- seed phrase
- mnemonic
- wallet JSON
- signing seed
- user-supplied transaction payload
- arbitrary instruction payload

The helper may import the Orca SDK and produce read-only position summaries or unsigned harvest instruction metadata. It must not sign, send, use wallet files, import tx-sender, call `buildAndSendTransaction`, call `setPayerFromBytes`, use Jito tips, or execute callback send paths.

The harvest authority object is public-key-only. Any signing method on the stub throws; Swift is the only signing authority.

## Harvest Plan Shape

The helper returns only safe proposal data:

- wallet public address
- position mint
- position address when available
- pool address when available
- token mint metadata when available
- expected raw fee/reward amounts when SDK exposes them
- instruction count
- writable account count
- signer account addresses
- program IDs
- instruction metadata with program ID, account metas, and base64 instruction data
- source label
- expiry timestamp

The helper does not return a signed transaction, serialized user-provided transaction payload, private key, seed phrase, wallet JSON, or raw SDK dumps.

## Native Review

Swift converts the helper instruction metadata into an unsigned Solana message and reviews it before approval.

The review checks:

- harvest source is `official-orca-sdk-harvest-instructions`
- selected wallet matches the plan wallet
- plan is fresh
- signer set contains only the selected wallet
- Whirlpool program is present
- instruction list is non-empty
- known safe Solana programs are labelled
- unknown programs and high writable counts are surfaced as warnings

Warnings do not automatically make a valid Orca harvest impossible, but they are visible before simulation and approval.

## Approval And Send

Harvest approval requires:

- selected wallet owns the discovered position mint
- unsigned message fingerprint matches the reviewed draft
- successful simulation
- wallet vault unlocked
- wallet secret unlocked
- LocalAuthentication success
- exact mainnet confirmation phrase when on mainnet
- existing devnet smoke acknowledgment

After approval, Swift signs locally, submits through `SolanaRPCClient`, waits for confirmation, and records safe audit events. The helper is not involved in signing or sending.

## Locked Actions

These remain locked:

- open position
- add liquidity
- remove liquidity
- close position
- swap

The UI may refer to the Orca tokenized owner record as an LP position, position token, or position mint. It must not introduce gallery, collectible, or roadmap copy around tokenized positions.

## Storage And Audit

Snapshots and audit may store:

- adapter status
- position count
- position mint/address
- pool address
- plan status
- simulation status
- signature after send
- timestamp
- safe failure category

They must not store raw transaction payloads, private material, wallet files, helper raw SDK responses, or signer data.
