# Developer Workstation Architecture

Developer Workstation is a native Solana builder workspace for inspecting projects, IDLs, accounts, logs, RPC reads, compute simulation, and guarded localnet/devnet program operations.

## Scope

- Top-level app section: `Developer Workstation`
- Internal sections: Overview, Projects, Toolchain, IDL Browser, Program Manager, Logs, Account Decoder, RPC Playground, Compute Lab, Localnet, Offline Signing, Activity
- D1-D3 program operations are localnet/devnet only
- Mainnet program ops locked is the default state for deploy, upgrade, close, and authority mutation
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

There is no shell, no eval, no pipes, and no raw terminal editor in Developer Workstation.

## Developer Wallet

Developer Workstation uses a separate localnet/devnet wallet stored in Keychain. It is not the main GORKH Wallet and is not available for mainnet program operations.

If a CLI command needs a keypair file, the keypair is written only to a secure temporary directory, chmod `0600` where possible, used for the single command, then deleted. Paths are redacted from logs and activity.

## Clusters

| Cluster | Read-only tools | Airdrop | Program ops |
| --- | --- | --- | --- |
| Localnet | Allowed | Allowed | Gated |
| Devnet | Allowed | Allowed | Gated |
| Testnet | Limited read-only | Blocked | Locked |
| Mainnet Beta | Read-only | Blocked | Locked |

## RPC Playground

Allowed RPC methods are read-only. `requestAirdrop` is available only through the guarded localnet/devnet faucet. `sendTransaction`, broad `getProgramAccounts`, and custom method text are blocked.

## Managed Toolchain Install

D2 added an explicit managed toolchain manifest at `docs/toolchains/gorkh-toolchain-manifest.json`; D3 adds explicit install statuses and an Anchor/AVM install plan. D5 adds a fixed Anchor/Rust compatibility matrix and Rust pinning strategy.

Managed installs are allowed only when a manifest entry has:

- HTTPS source URL
- sha256
- versioned install directory under `Application Support/GORKH/Toolchains`
- executable relative path
- license/source note

Entries with missing source or checksum are shown as blocked. This repository does not commit toolchain binaries and does not claim bundled Solana, Anchor, Rust, Node, npm, or Git binaries unless app resources actually contain them.

Anchor/AVM follows a separate verified-tooling path:

- existing `anchor` is detected and verified with `anchor --version`
- existing `avm` can try fixed `avm self-update` when supported
- existing `avm` can run fixed `avm install latest` / `avm use latest` or `avm install 1.0.2` / `avm use 1.0.2`
- Cargo can prepare fixed `cargo install --git https://github.com/solana-foundation/anchor avm --force` from the official Anchor repository only after explicit tooling approval
- if current Rust cannot compile the chosen Anchor candidate, `rustup toolchain install stable` or `rustup toolchain install 1.95.0` can be prepared as fixed commands when rustup is present
- AVM/Cargo commands may use `RUSTUP_TOOLCHAIN=stable` or `RUSTUP_TOOLCHAIN=1.95.0` as a scoped command environment override
- GORKH does not run `rustup default` and does not mutate the global Rust default
- no Cargo/AVM command runs automatically
- official prebuilt Anchor binary install is blocked until an official release asset URL and SHA-256 are pinned

Archive extraction must reject absolute paths, parent traversal, backslashes, and null bytes. No unverified installer execution is allowed.

## Compatibility Matrix

The compatibility panel records current versions, fixed candidates, and blockers:

- Anchor candidates are fixed to `latest` and `1.0.2`
- the D6 recommended candidate is AVM `latest`, expected to resolve to Anchor CLI `1.0.2`
- Rust candidates are fixed to `stable` and `1.95.0`
- arbitrary Anchor or Rust version strings are rejected
- prebuilt Anchor artifacts stay blocked until official source URL and SHA-256 are pinned

D4 proved that Anchor `0.30.1` does not activate under local Rust/Cargo `1.94.0`; D6 superseded the old D5 `0.31.1` / `1.79.0` plan with latest stable Anchor/Rust targets. D7 replaced local AVM `0.30.1` with AVM `1.0.2` through the fixed official Cargo reinstall command, activated `anchor-cli 1.0.2`, and completed the sample localnet deploy smoke. `avm use latest` still has a local runtime panic, so the UI continues to show the AVM update state separately from Anchor CLI readiness.

## Local Validator

D3 keeps a fixed local validator lifecycle:

- detect localnet RPC health at `http://127.0.0.1:8899`
- start `solana-test-validator` only from a validated executable path
- use an Application Support ledger path
- stream bounded redacted logs
- stop only a validator process started by GORKH
- never stop an externally running validator

The fixed start command uses `solana-test-validator` with explicit ledger, RPC port, faucet port, and ledger size arguments. Reset is a gated option.

## Program Manager

Developer Workstation exposes policy evaluation and fixed command previews for:

- `anchor build`
- `anchor deploy`
- `solana program deploy`
- `solana program show`
- `solana program close`
- `solana program set-upgrade-authority`

Build/deploy/close/authority operations require a trusted project, required toolchain, separate developer wallet, explicit approval, and localnet/devnet cluster. Mainnet is locked.

D3 can prepare fixed localnet build/deploy command previews from the selected trusted project and toolchain snapshot. Localnet smoke is staged through `scripts/workstation-localnet-smoke.sh --check`, `--build-sample`, `--deploy-sample`, and `--full-localnet`.

## IDL and Account Decode

D2/D3 deepen IDL parsing by showing instruction accounts, signer/writable counts, account discriminators, types, events, and errors.

The account decoder can match Anchor account discriminators and decode simple primitive Borsh fields:

- bool
- signed and unsigned 8/16/32/64-bit integers
- string with a bounded length
- pubkey

Complex vectors, arrays, options, nested structs, and unknown layouts fall back to an honest unavailable state.

## Offline Signing Foundation

Offline signing is a foundation only. It can describe and prepare future unsigned/signed file review workflows, but it does not sign or broadcast.
