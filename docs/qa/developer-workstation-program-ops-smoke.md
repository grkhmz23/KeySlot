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

## D7 Modern AVM Path

Phase D7 adds the modern AVM activation path:

- `avm self-update` when supported by the installed AVM
- fixed fallback `cargo install --git https://github.com/solana-foundation/anchor avm --force`
- fixed `avm install latest`
- fixed `avm use latest` when usable
- `anchor --version`
- official prebuilt Anchor binary install remains blocked unless a release asset URL and SHA-256 are pinned

D7 result:

- old AVM `0.30.1` did not support `self-update`.
- fixed Cargo reinstall from the official Anchor repository installed AVM `1.0.2`.
- `avm install latest` activated `anchor-cli 1.0.2`.
- `avm use latest` still hit a local AVM runtime panic, but `anchor --version` remained active.
- sample Anchor project was updated for Anchor `1.0.2`.
- full localnet smoke succeeded after allowing localhost validator port binding.
- Localnet program id: `9aR9XnArCREYz86Y7kqy2W9iKYnWT8CSbEjnBTAQLvsJ`.
- Deploy signature: `5FS38zAwXX4SP3VVRi1r1ubHHXYFdsv7S9WBYCdFbG4uR8ANWTyy6u9jAqt1Bq8YNby61xTu4DE94eQ8KA6Ed2To`.
- Temporary keypair files were created only inside the smoke temp directory and cleanup was confirmed.
- Mainnet program operations remain locked.

## D8 Program Ops Certification

D8 adds a safe evidence store and gated previews for localnet/devnet program management:

- Program evidence is stored as redacted JSON under Application Support.
- The Workstation UI shows localnet smoke evidence, program id, signature, tool versions, IDL path summary, artifact summary, and temp key cleanup status.
- AVM degraded state is non-blocking only when `anchor --version` succeeds.
- Devnet certification is manual and gated by Devnet selection, trusted project, active toolchain, separate developer wallet, exact confirmation, and fixed command preview.
- Devnet deploy is not run automatically; `scripts/workstation-program-ops-smoke.sh --devnet-sample --confirm-devnet` skips unless `GORKH_WORKSTATION_DEVNET_DEPLOY=1` is also set.
- Upgrade, close, authority transfer, and authority revoke previews are localnet/devnet only.

Required phrases:

- Upgrade: `I understand this upgrades a Solana program on localnet or devnet.`
- Close: `I understand this closes a Solana program and may be irreversible.`
- Revoke authority: `I understand this revokes upgrade authority and may be irreversible.`

Preview script:

- `scripts/workstation-program-ops-smoke.sh --program-show --cluster localnet --program-id <public-program-id>`
- `scripts/workstation-program-ops-smoke.sh --upgrade-preview --cluster devnet --program-id <public-program-id>`
- `scripts/workstation-program-ops-smoke.sh --close-preview --cluster localnet --program-id <public-program-id>`
- `scripts/workstation-program-ops-smoke.sh --authority-preview --cluster devnet --program-id <public-program-id>`

D8 smoke result:

- `scripts/workstation-program-ops-smoke.sh --authority-preview --cluster devnet --program-id 11111111111111111111111111111111` passed and printed fixed localnet/devnet-safe authority previews only.
- `scripts/workstation-program-ops-smoke.sh --localnet-sample` passed outside the sandbox after a sandboxed validator faucet bind was blocked.
- Program id: `4rQMkzANcjjinzHd47mp1Kj2W7pokFfJxmxMsjQPdnfJ`.
- Deploy signature: `3UwxdFwWT3WhLfKT5Gssf3Z19pawgA4x5KwWbXqNzUJAyeSmiU7LHWBhWuTr363QjvDivfxSoheVbF883foX9r8r`.
- Temp keypair cleanup: confirmed by successful smoke exit.

Mainnet program operations remain locked.
