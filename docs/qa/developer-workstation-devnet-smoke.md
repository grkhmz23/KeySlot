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

Devnet certification path exists and is gated. A live devnet deploy was not run during the initial D8 commit because it required explicit local funding and `GORKH_WORKSTATION_DEVNET_DEPLOY=1`.

## D8 Follow-Up Live Devnet Evidence

After the D8 commit, a separate Developer Workstation dev wallet was funded on devnet and used for a manual, explicit devnet-only sample deploy.

- Developer wallet public key: `6iiYaBaxJStXt3BQhfjNTBo81S1f6fxAwfYtjYvNM98k`
- Toolchain: Anchor CLI `1.0.2`, Solana CLI `3.1.10`, Cargo `1.95.0`
- Program id: `9jZcQzNhUkXpEdyUGN4xsTnJ1N2xdaSWwkQiTDQtHncV`
- Deploy signature: `3PnyFV1G7whcj6291xf7BWMeXoqhy3s5mE5LdjKCRoT3TAacQnbuVAzuJ5TzK72xZQsnh4kZx8TXqR4fWRUoQieE`
- ProgramData address: `FLfM6b2QhjrmanjZ4aJhJ7H37Nbt3skGxEP9uxS2vEHX`
- Last deployed slot: `461478156`
- Upgrade authority: `6iiYaBaxJStXt3BQhfjNTBo81S1f6fxAwfYtjYvNM98k`
- Remaining developer wallet balance after deploy: `9.12077332 SOL`
- Disposable sample build directory cleanup: confirmed

No mainnet operation was run. No keypair contents, private keys, seed phrases, or wallet JSON were recorded.
