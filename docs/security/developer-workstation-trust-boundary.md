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

## Key Boundary

Developer Workstation uses a separate Keychain-backed dev wallet for localnet/devnet. It does not use the main GORKH Wallet, the Agent wallet, or any private/Cloak state.

Temporary keypair files are allowed only during a localnet/devnet command. They must be deleted immediately and never logged.

## Mainnet Boundary

D1 mainnet support is read-only:

- account lookup
- IDL browsing
- logs
- safe RPC reads
- Transaction Studio review

Mainnet program deploy, upgrade, close, and authority mutation are locked.

## Redaction

Activity and command output are redacted. The Workstation must not log wallet JSON, key material, API keys, temporary keypair paths, or full raw command output if it contains sensitive fields.
