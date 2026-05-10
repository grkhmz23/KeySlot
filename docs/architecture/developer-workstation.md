# Developer Workstation Architecture

Developer Workstation is a native Solana builder workspace for inspecting projects, IDLs, accounts, logs, RPC reads, compute simulation, and guarded localnet/devnet program operations.

## Scope

- Top-level app section: `Developer Workstation`
- Internal sections: Overview, Projects, Toolchain, IDL Browser, Program Manager, Logs, Account Decoder, RPC Playground, Compute Lab, Localnet, Offline Signing, Activity
- D1 program operations are localnet/devnet only
- Mainnet program ops locked is the default D1 state for deploy, upgrade, close, and authority mutation
- Mainnet program deploy, upgrade, close, and authority mutation are locked pending a reviewed future phase
- Transaction signing and broadcast remain outside Transaction Studio and Workstation review surfaces

## Trust Boundary

Imported projects start untrusted. Browsing metadata, IDLs, and docs is allowed, but running build or deployment commands is blocked until the user enters:

`I trust this project and understand build scripts may run local code.`

This is required because Solana projects can execute local code during builds through Cargo build scripts, proc macros, npm scripts, Anchor hooks, or workspace scripts.

## Toolchain Resolution

The managed toolchain architecture is explicit even when binaries are not bundled yet.

Toolchain detection checks fixed locations only:

- Bundled app resources, if packaged
- Managed path under `Application Support/GORKH/Toolchains`
- Trusted absolute system paths such as `/opt/homebrew/bin`, `/usr/local/bin`, and `/usr/bin`
- PATH entries only after resolving to absolute, safe directories

The resolver never accepts arbitrary user-entered executable paths.

## Command Execution

All process execution goes through fixed command plans:

- executable path
- argument array
- optional working directory
- timeout
- redacted output

There is no shell, no eval, no pipes, and no raw terminal editor in D1.

## Developer Wallet

Developer Workstation uses a separate localnet/devnet wallet stored in Keychain. It is not the main GORKH Wallet and is not available for mainnet program operations in D1.

If a CLI command needs a keypair file, the keypair is written only to a secure temporary directory, chmod `0600` where possible, used for the single command, then deleted. Paths are redacted from logs and activity.

## Clusters

| Cluster | Read-only tools | Airdrop | Program ops |
| --- | --- | --- | --- |
| Localnet | Allowed | Allowed | Gated |
| Devnet | Allowed | Allowed | Gated |
| Testnet | Limited read-only | Blocked | Locked |
| Mainnet Beta | Read-only | Blocked | Locked |

## RPC Playground

Allowed RPC methods are read-only. `requestAirdrop` is available only through the guarded localnet/devnet faucet. `sendTransaction`, broad `getProgramAccounts`, and custom method text are blocked in D1.

## Program Manager

D1 exposes policy evaluation and fixed command previews for:

- `anchor build`
- `anchor deploy`
- `solana program deploy`
- `solana program show`
- `solana program close`
- `solana program set-upgrade-authority`

Build/deploy/close/authority operations require a trusted project, required toolchain, separate developer wallet, explicit approval, and localnet/devnet cluster. Mainnet is locked.

## Offline Signing Foundation

Offline signing is a foundation only in D1. It can describe and prepare future unsigned/signed file review workflows, but it does not sign or broadcast.
