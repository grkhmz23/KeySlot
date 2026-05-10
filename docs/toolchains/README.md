# GORKH Managed Toolchains

Developer Workstation resolves tools in this order:

1. Bundled app resources, if release packaging includes them.
2. Managed installs under `~/Library/Application Support/GORKH/Toolchains/`.
3. Validated absolute system paths such as Homebrew and `/usr/bin`.

D3 does not commit toolchain binaries. The manifest in this directory is an install contract, not a binary package.

## Manifest Requirements

Every installable entry must include:

- tool id
- version
- platform and architecture
- HTTPS source URL
- sha256
- executable relative path
- install strategy
- license/source note

Entries without a verified source and sha256 are shown as blocked. GORKH must not run unverified installers, bootstrap scripts, or curl-pipe-sh flows.

Anchor is handled separately from archive downloads:

- if `anchor` already resolves from a trusted path, GORKH verifies it with `anchor --version`
- if `avm` already resolves, GORKH can prepare fixed `avm install latest` / `avm use latest` or `avm install 1.0.2` / `avm use 1.0.2` commands
- if `avm` is missing but Cargo resolves, GORKH can prepare a fixed Cargo command to install AVM from the official Anchor repository after explicit tooling-install approval
- if Cargo is missing, Anchor install is blocked

No Anchor/AVM install command runs automatically.

## D6 Latest Stable Strategy

D4 showed that `avm install 0.30.1` fails under the local Rust/Cargo 1.94 toolchain while compiling `time 0.3.29`. D5 recorded a fixed compatibility matrix; D6 supersedes that older path with the latest stable targets from official upstream docs and releases:

- Anchor candidates: `latest`, `1.0.2`
- recommended candidate: AVM `latest`, expected resolved Anchor CLI `1.0.2`
- Rust candidates: `stable`, `1.95.0`
- Rust pinning must use `RUSTUP_TOOLCHAIN=stable` or `RUSTUP_TOOLCHAIN=1.95.0` only for approved AVM/Cargo commands
- Solana CLI `3.1.10` is detected locally and matches the Anchor 1.0.x compatible Solana CLI line
- GORKH must not run `rustup default`
- GORKH must not install Rust through curl-pipe-sh or any unverified installer
- prebuilt Anchor artifacts remain blocked until an official URL and SHA-256 are pinned

If `rustup` is present, Developer Workstation can prepare the fixed preview:

`rustup toolchain install stable`

or the explicit fallback:

`rustup toolchain install 1.95.0`

Then the approved Anchor activation path can run AVM with `latest` or `1.0.2` and the fixed Rust environment for that command only. This does not change the global Rust default.

## Install Location

Managed tools install into versioned directories:

- `solana/<version>/`
- `avm/<version>/`
- `anchor/<version>/`
- `rustc/<version>/`
- `cargo/<version>/`
- `node/<version>/`
- `npm/<version>/`
- `git/<version>/` if managed Git is added later

Archive extraction must reject absolute paths, parent traversal, backslashes, and null bytes. Executables are validated after install before they can be used.

## Current D3 State

The manifest is explicit and honest:

- Solana, Node, and future archive installs remain blocked until official artifact URLs and sha256 hashes are pinned.
- Rust/Cargo, npm, and Git are detected-only unless packaged later.
- Anchor is installed through AVM when AVM/Cargo are present and the user approves the fixed tooling operation.
- Bundled tools are not claimed unless app resources actually contain validated executables.

## Current D6 State

- D6 targets Anchor latest stable, expected `1.0.2`.
- D6 targets Rust stable, expected `1.95.0`.
- Solana CLI `3.1.10` remains acceptable when detected.
- `rustup toolchain install stable` activated Rust/Cargo `1.95.0` locally without a GORKH `rustup default` command.
- `avm install latest` resolved Anchor CLI `1.0.2` but failed during native linking on this machine.
- `anchor --version` still reports `Anchor version not set`.
- Full localnet deploy smoke remains blocked until Anchor activates.
- Anchor activation and localnet smoke evidence are recorded in `docs/qa/developer-workstation-localnet-smoke.md`.

## D7 Modern AVM / Anchor Activation

D7 keeps the same official latest targets and adds a modern AVM path:

- try fixed `avm self-update` when AVM supports it
- if self-update is unsupported, use fixed `cargo install --git https://github.com/solana-foundation/anchor avm --force`
- run fixed `avm install latest` and verify the resolved `anchor --version`
- keep official prebuilt Anchor binary install blocked until a release asset URL and SHA-256 are pinned

Local evidence:

- `avm self-update` was unsupported by the old local AVM `0.30.1`.
- the fixed Cargo reinstall from the official Anchor repository succeeded and installed AVM `1.0.2`.
- `avm install latest` activated `anchor-cli 1.0.2`.
- `avm use latest` still reported an AVM runtime panic in the local system-configuration/reqwest path, but `anchor --version` remained usable.
- full localnet smoke built the sample project and deployed a temporary localnet program.
- no bundled binaries are claimed and no official prebuilt binary install is enabled without SHA-256.

Anchor build uses upstream Solana/Anchor build tooling and may download SBPF platform tooling during the build. This is why project trust and explicit command approval remain required before any build or deploy operation.

## D8 Program Ops Evidence

D8 keeps the AVM warning visible in Developer Workstation: `avm use latest` may panic locally, but it is non-blocking while `anchor --version` succeeds.

Program-operation evidence is stored as redacted JSON under Application Support. It stores public program ids, signatures, tool versions, safe command/log summaries, IDL/artifact path summaries, and temp key cleanup status. It does not store keypair file contents, private keys, raw command environments, or unredacted logs.
