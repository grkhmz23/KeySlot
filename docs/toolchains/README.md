# GORKH Managed Toolchains

Developer Workstation resolves tools in this order:

1. Bundled app resources, if release packaging includes them.
2. Managed installs under `~/Library/Application Support/GORKH/Toolchains/`.
3. Validated absolute system paths such as Homebrew and `/usr/bin`.

D2 does not commit toolchain binaries. The manifest in this directory is an install contract, not a binary package.

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

Entries without a verified source and sha256 are shown as blocked. GORKH must not run unverified installers or bootstrap scripts.

## Install Location

Managed tools install into versioned directories:

- `solana/<version>/`
- `anchor/<version>/`
- `rustc/<version>/`
- `cargo/<version>/`
- `node/<version>/`
- `npm/<version>/`
- `git/<version>/` if managed Git is added later

Archive extraction must reject absolute paths, parent traversal, backslashes, and null bytes. Executables are validated after install before they can be used.

## Current D2 State

The manifest intentionally uses blocked placeholder entries until release packaging provides audited sources and hashes. The app still detects bundled, managed, and system tools honestly.
