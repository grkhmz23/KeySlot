# Developer Workstation Trust Boundary

Developer Workstation treats imported code as potentially unsafe until explicitly trusted.

## Why Imported Projects Are Untrusted

Build and deploy tooling can run local code:

- Cargo `build.rs`
- proc macros
- Anchor build hooks
- npm scripts
- package postinstall scripts
- workspace scripts

For that reason, import only scans metadata and never runs a command.

## Trust Gate

Before build, deploy, upgrade, close, or authority operations, the user must enter:

`I trust this project and understand build scripts may run local code.`

Untrusted projects may be browsed and their IDLs may be inspected. They cannot execute build tooling.

## Command Boundary

Developer Workstation has no arbitrary shell, no raw command editor, and no custom mutating RPC console. Commands are built from fixed Swift command builders and passed to `Process` as executable URL plus argument array.

Command previews must show what will run before any approved operation starts.

## Toolchain Install Boundary

Toolchain install is separate from project trust. Managed installs require a manifest entry with HTTPS source, sha256, executable relative path, and license/source note.

Missing hashes block install. GORKH must not run unverified bootstrap scripts or curl-pipe-sh flows. Archive entries are rejected if they are absolute, traverse parents, contain backslashes, or contain null bytes.

If AVM must be installed through Cargo, that is treated as trusted tooling install risk and requires explicit confirmation. GORKH prepares only fixed Cargo arguments for the official Anchor repository; it does not run arbitrary package-manager commands or project scripts.

Rust compatibility pinning is also explicit and fixed. GORKH may prepare `rustup toolchain install 1.79.0` when rustup is already present, and may scope `RUSTUP_TOOLCHAIN=1.79.0` to approved AVM/Cargo commands. It must not run `rustup default`, install rustup through a bootstrap script, or accept arbitrary Rust version strings.

## Key Boundary

Developer Workstation uses a separate Keychain-backed dev wallet for localnet/devnet. It does not use the main GORKH Wallet, the Agent wallet, or any private/Cloak state.

Temporary keypair files are allowed only during a localnet/devnet command. They must be deleted immediately and never logged.

## Mainnet Boundary

Mainnet support is read-only:

- account lookup
- IDL browsing
- logs
- safe RPC reads
- Transaction Studio review

Mainnet program deploy, upgrade, close, and authority mutation are locked.

## Local Validator Boundary

Local validator start/stop is localnet-only. GORKH may start a validator process through a fixed command builder and may stop only the validator process it started.

Validator logs are bounded and redacted. Ledger data belongs under Application Support, not inside the repository.

Resetting the local validator ledger requires the exact phrase:

`Reset local validator ledger`

## Redaction

Activity and command output are redacted. The Workstation must not log wallet JSON, key material, API keys, temporary keypair paths, or full raw command output if it contains sensitive fields.
