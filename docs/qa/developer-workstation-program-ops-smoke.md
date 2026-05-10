# Developer Workstation Program Ops Smoke

This smoke is for localnet/devnet program-operation readiness. Do not use mainnet program operations.

## Preconditions

- Toolchain check completed.
- Project imported.
- Project explicitly trusted.
- Developer Workstation dev wallet generated.
- Cluster is localnet or devnet.
- No main GORKH Wallet key material is used.

## Localnet / Devnet Build

- Operation: Anchor build.
- Expected: requires Anchor CLI and trusted project.
- Expected command preview: fixed `anchor build`.
- Expected: blocked if project is untrusted or Anchor CLI missing.
- Expected: command preview is prepared through a fixed builder only.

## Localnet / Devnet Deploy

- Operation: Solana program deploy.
- Expected: requires Solana CLI, trusted project, developer wallet, and artifact path.
- Expected command preview uses fixed `solana program deploy` arguments.
- Expected: no arbitrary flags.
- Expected: deployment uses the separate Developer Workstation dev wallet, not the main wallet.

## Program Show

- Operation: Solana program show.
- Expected: read-only command allowed when Solana CLI is available and a program id is provided.
- Expected: mainnet show is read-only only.

## Close / Authority Operations

- Operation: program close or set upgrade authority.
- Expected: localnet/devnet only.
- Expected: destructive-operation phrase required.
- Expected phrase:

`I understand this local/devnet program operation can change or close a program.`

## Mainnet Lock

- Select mainnet-beta.
- Try deploy, close, or authority mutation.
- Expected: blocked with “Locked pending reviewed mainnet program-ops phase.”

## Temporary Keypair Handling

- If a command is actually run in a future manual smoke:
  - temp keypair file is created in a secure temp directory
  - file mode is `0600` where possible
  - command logs redact the path
  - temp directory is deleted immediately after command

## Evidence

- Record command preview only.
- Record success/failure status.
- Do not record private key material, wallet JSON, or local temp file contents.

## Localnet Sample Smoke

Use:

`scripts/workstation-localnet-smoke.sh --check`

Expected:

- sample Anchor project exists
- tool availability is reported
- no build or deploy runs in check mode

Staged live modes:

- `scripts/workstation-localnet-smoke.sh --start-validator`
- `scripts/workstation-localnet-smoke.sh --build-sample`
- `scripts/workstation-localnet-smoke.sh --deploy-sample --skip-start-validator`
- `scripts/workstation-localnet-smoke.sh --full-localnet`

Use live modes only when Solana CLI, solana-test-validator, and Anchor CLI are installed locally and localnet use is intentional. The full path creates a temporary keypair file, starts a validator if needed, builds the sample, deploys to localnet with fixed `solana program deploy`, verifies with `solana program show`, and deletes temporary files on exit.

## D4 Anchor Activation Evidence

Phase D4 attempted the approved Anchor activation path:

- Cargo was available: `cargo 1.94.0`.
- AVM was installed and available: `avm 0.30.1`.
- Anchor remained unavailable because `anchor --version` returned `Anchor version not set`.
- `avm install 0.30.1` failed while compiling `anchor-cli 0.30.1`; dependency `time 0.3.29` failed under the local Rust/Cargo 1.94 toolchain.

The localnet program deploy smoke did not deploy a sample program in D4. The smoke script now validates `anchor --version` before starting a local validator, so `scripts/workstation-localnet-smoke.sh --full-localnet` skips safely when the Anchor shim exists but is not usable.

Recorded D4 result:

- Build/deploy status: blocked by Anchor activation.
- Program id: none.
- Temporary keypair: not created by the final full-localnet smoke path.
- Mainnet program operations: still locked.

## D5 Compatibility Path

Phase D5 adds a fixed compatibility matrix:

- Anchor candidates: `0.31.1`, `0.30.1`
- historical recommended Anchor candidate: `0.31.1`
- Rust pin candidate: `1.79.0`
- detected local Rust/Cargo: `1.94.0`
- detected rustup: `1.29.0`
- detected AVM: `0.30.1`

The D5 strategy was to prepare `rustup toolchain install 1.79.0` with explicit tooling approval, then run fixed AVM install/use commands for Anchor `0.31.1` with `RUSTUP_TOOLCHAIN=1.79.0` scoped to that command environment. GORKH does not run `rustup default`, does not accept arbitrary version strings, and does not use unverified install scripts.

D5 did not produce a localnet deploy. Anchor remains inactive, so localnet build/deploy continues to skip safely before validator startup.

## D6 Latest Stable Path

Phase D6 supersedes the old D5 recommendation with the current latest stable targets:

- Anchor channel: `latest`
- expected resolved Anchor CLI: `1.0.2`
- explicit Anchor fallback: `1.0.2`
- Rust channel: `stable`
- expected resolved Rust: `1.95.0`
- explicit Rust fallback: `1.95.0`
- Solana CLI: local `solana-cli 3.1.10`

Fixed D6 activation commands:

- `rustup toolchain install stable`
- `avm install latest`
- `avm use latest` only after install succeeds
- `anchor --version`

D6 result:

- Rust stable and explicit `1.95.0` probes report `rustc 1.95.0` / `cargo 1.95.0`.
- `avm install latest` resolved to Anchor CLI `1.0.2` but failed during native linking because the local Apple linker/LTO reader could not parse Rust 1.95/LLVM 22 bitcode objects from SPL proof-generation dependencies.
- `anchor --version` still reports `Anchor version not set`.
- Full localnet deploy remains blocked by Anchor activation.
- Program id: none.
- Mainnet program operations remain locked.
