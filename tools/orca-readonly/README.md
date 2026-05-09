# GORKH Orca Whirlpools Helper

This helper is a fixed-command boundary for Orca Whirlpools position monitoring and unsigned harvest planning. It accepts only public wallet addresses, position mints, network, request ID, and optional RPC URL. It never accepts wallet private keys, signing seeds, wallet JSON, user-supplied transaction payloads, or arbitrary instruction payloads.

Allowed commands:

- `health`
- `env-check`
- `positions`
- `harvest-plan`

The `positions` command uses the official `@orca-so/whirlpools` read-only `fetchPositionsForOwner` function with `@solana/kit` RPC.

The `harvest-plan` command verifies the selected position mint belongs to the requested owner, then calls `harvestPositionInstructions` to return unsigned instruction metadata only. It does not sign, send, call callback send paths, use tx-sender, load wallet files, or use Jito tips. Native Swift review, simulation, approval, signing, sending, confirmation, and audit remain mandatory.

Liquidity action methods outside harvest, tx-sender flows, private-key/file-wallet loading, and transaction send helpers are denylisted and tested.

Reviewed public constants:

- Whirlpool Program ID: `whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc`
- Mainnet WhirlpoolConfig: `2LecshUwdy9xi7meFgHtFJQNSKk4KdTrcpvaB56dP2NQ`
- Devnet WhirlpoolConfig: `FcrweFY1G9HJAHG5inkGB6pKg1HZ6x9UC2WioAfWrGkR`
- Orca public API base: `https://api.orca.so/v2/solana`

The public API is reserved for optional metadata/pool enrichment. It must not replace on-chain owner position discovery.
