# GORKH Orca Read-Only Helper

This helper is a fixed-command boundary for Orca Whirlpools position monitoring. It accepts only public wallet addresses, network, request ID, and optional RPC URL. It never accepts wallet private keys, signing seeds, wallet JSON, transaction payloads, or instruction payloads.

Allowed commands:

- `health`
- `env-check`
- `positions`

The `positions` command uses the official `@orca-so/whirlpools` read-only `fetchPositionsForOwner` function with `@solana/kit` RPC. Liquidity action methods, tx-sender flows, private-key/file-wallet loading, and transaction builders are denylisted and tested.

Reviewed public constants:

- Whirlpool Program ID: `whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc`
- Mainnet WhirlpoolConfig: `2LecshUwdy9xi7meFgHtFJQNSKk4KdTrcpvaB56dP2NQ`
- Devnet WhirlpoolConfig: `FcrweFY1G9HJAHG5inkGB6pKg1HZ6x9UC2WioAfWrGkR`
- Orca public API base: `https://api.orca.so/v2/solana`

The public API is reserved for optional metadata/pool enrichment. It must not replace on-chain owner position discovery.
