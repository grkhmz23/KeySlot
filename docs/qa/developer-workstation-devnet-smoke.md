# Developer Workstation Devnet Smoke

This checklist certifies the controlled devnet program-operation path. It is not automatic and must not be run with mainnet.

## Preconditions

- Anchor CLI is active and verified with `anchor --version`.
- Solana CLI is active and verified with `solana --version`.
- A Developer Workstation dev wallet exists and is separate from the main GORKH wallet.
- The project is explicitly trusted.
- Devnet is selected.
- The dev wallet is funded with a small capped devnet airdrop.
- Command preview is reviewed before execution.

## Devnet Funding

Use the Developer Workstation faucet helper with Devnet selected.

Expected:

- `requestAirdrop` is capped at 2 SOL.
- `requestAirdrop` is blocked on mainnet.
- The airdrop event stores only safe summary fields and the public signature.

## Certification Script

Use:

`scripts/workstation-program-ops-smoke.sh --devnet-sample --confirm-devnet`

Current behavior:

- Without `--confirm-devnet`, the script skips safely.
- Without `GORKH_WORKSTATION_DEVNET_DEPLOY=1`, the script skips safely after confirmation.
- Mainnet is not accepted as a script cluster.
- No arbitrary flags are accepted.

## Program Operations

Required approval phrases:

- Upgrade: `I understand this upgrades a Solana program on localnet or devnet.`
- Close: `I understand this closes a Solana program and may be irreversible.`
- Revoke authority: `I understand this revokes upgrade authority and may be irreversible.`

Expected:

- Deploy requires trusted project, dev wallet, active toolchain, Devnet, fixed command preview, and explicit approval.
- Upgrade requires the upgrade phrase.
- Close requires the close phrase.
- Authority transfer/revoke requires exact phrase gates.
- Mainnet program operations remain locked.

## D8 Status

Devnet certification path exists and is gated. A live devnet deploy was not run in D8. The blocker is intentional: devnet deploy requires explicit local funding and `GORKH_WORKSTATION_DEVNET_DEPLOY=1`.
