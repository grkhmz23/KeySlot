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
- if `avm` already resolves, GORKH can prepare fixed `avm install 0.30.1` and `avm use 0.30.1` commands
- if `avm` is missing but Cargo resolves, GORKH can prepare a fixed Cargo command to install AVM from the official Anchor repository after explicit tooling-install approval
- if Cargo is missing, Anchor install is blocked

No Anchor/AVM install command runs automatically.

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
