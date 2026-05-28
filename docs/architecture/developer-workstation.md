# Developer Workstation Architecture

Developer Workstation is a native Solana builder workspace for inspecting projects, IDLs, accounts, logs, RPC reads, compute simulation, and guarded localnet/devnet program operations.

## Scope

- Top-level app section: `Developer Workstation`
- Internal sections: Overview, Project Brain, Transaction Debugger, PDA Explorer, IDL Drift, Fixture Studio, Test Workbench, Compute Regression, Release Manager, Security Scanner, Frontend Assistant, Workstation Agent, Projects, Toolchain, IDL Browser, Program Manager, Logs, Account Decoder, RPC Playground, Compute Lab, Localnet, Offline Signing, Activity
- D1-D3 program operations are localnet/devnet only
- Mainnet program ops locked is the default state for deploy, upgrade, close, and authority mutation
- Mainnet program deploy, upgrade, close, and authority mutation are locked pending a reviewed future phase
- Program operation evidence is stored as redacted JSON under Application Support and contains only public ids, signatures, tool versions, status, and safe summaries
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

D8 adds the certification layer around these program operations:

- localnet evidence from the D7 Anchor sample deploy is visible in the Workstation UI
- devnet certification is available only with Devnet selected, trusted project, active toolchain, separate developer wallet, explicit confirmation, and fixed command preview
- devnet airdrop uses a capped helper and remains blocked on mainnet
- upgrade, close, transfer-authority, and revoke-authority previews are localnet/devnet only
- destructive operations require exact phrases before a command preview is allowed
- `avm use latest` panic is surfaced as a degraded AVM warning when `anchor --version` still succeeds

The Program Manager does not accept raw terminal input or arbitrary flags. Evidence capture records safe summaries only and never stores temporary keypair file contents.

D9/Phase 6 upgrades the Program Manager into a Deployment Release Manager while preserving the existing Program Manager gates and evidence model:

- panels: Build / Deploy, Upgrade Preview, Authority Preview, Release Records, and Preflight Checks
- release records are created only from real program-operation evidence
- release records add local SHA-256 hashes for available artifact and IDL files, tool versions, command summary, optional fixed-command Git metadata, public upgrade authority, evidence id, and redacted failure summary
- preflight checks verify project trust, localnet/devnet cluster policy, active toolchain, separate Developer Workstation wallet, program id consistency across `declare_id!`, `Anchor.toml`, IDL metadata/address, selected deploy target, artifact presence, IDL availability, IDL drift warning state, upgrade authority availability, balance-check availability, temporary keypair lifecycle policy, fixed command preview, and explicit approval state
- Git metadata is optional and may use only fixed commands: `git rev-parse HEAD` and `git status --porcelain`
- artifact and IDL hashing is local-only; records store path summaries and hashes, not full private paths
- mainnet deploy, upgrade, close, transfer authority, and revoke authority remain locked

## Developer Workstation 2.0

Workstation 2.0 adds a Solana-native intelligence layer without changing the execution boundary:

- Project Brain scans the imported project folder read-only and generates a structured Solana graph: detected files, toolchain hints, programs, IDLs, instructions, account types, PDA candidates, clients, tests, warnings, unsupported findings, and confidence.
- Transaction Debugger fetches public signatures with read-only `getTransaction`, decodes fetched transactions through the existing review-only decoder, parses logs/compute/error lines, maps custom errors to loaded IDL errors when exact codes are present, compares accounts against loaded IDL and Project Brain context, and stores redacted bounded evidence. It never signs or broadcasts.
- PDA Explorer reads Anchor IDL PDA metadata and derives only when the seeds are concrete. It also supports manual PDA derivation with UTF-8, pubkey, raw hex, byte-list, and little-endian integer seeds. Dynamic account or argument seeds are reported as unavailable instead of guessed.
- IDL Drift Detector compares local parsed IDLs and Project Brain findings for program id mismatches, instruction/account shape changes, account field changes, error mapping changes, event changes, discriminator changes, and stale generated client hints. On-chain IDL drift remains unsupported unless a reviewed read-only Anchor IDL fetcher is added.
- Fixture Studio reports real localnet sample/evidence availability only. It does not fabricate account state or snapshots.
- Test Workbench detects Anchor, Cargo, native Solana, LiteSVM, Mollusk, and Trident signals from project files. Anchor and Cargo test runs use fixed command builders only, require a trusted project, require explicit approval, capture bounded redacted output, and store safe evidence. LiteSVM, Mollusk, and Trident are shown as detected-but-unsupported until reviewed fixed builders exist.
- Compute Regression parses compute-unit lines from real Compute Lab simulation logs, Transaction Debugger logs, or Test Workbench output. Baselines can be selected only from stored real measurements. No compute baseline is fabricated.
- Release Manager summarizes trust, IDL, selected cluster, and stored evidence readiness while keeping mainnet writes locked.
- Security Scanner reports findings from imported metadata, toolchain state, selected cluster, and trust state.
- Frontend Assistant inspects real TypeScript/React frontend files, compares them with loaded IDL and Project Brain metadata, previews safe integration drafts, and writes only approved draft files under a scoped `gorkh/frontend-assistant/` path.
- Workstation Agent exposes a typed Swift `DeveloperAgentToolRegistry` with explicit modes, schemas, approval requirements, cluster restrictions, and redacted evidence policies.

The Workstation Agent is separate from the global Agent. If no AI provider is configured, it shows an honest unavailable state for AI chat and still allows deterministic tool workflows. Tool calls are typed async Swift calls into existing Developer Workstation services.

Supported tool modes:

- Read-only: inspect Project Brain, loaded IDL, account decode fixtures, transaction debug reports, localnet status, toolchain state, release evidence, security findings, frontend findings, and safe RPC permissions.
- Suggest: generate deterministic next-step summaries, compute measurements from real logs, Program Manager preflight summaries, and frontend draft previews.
- Patch: reserved for approved file-writing flows; current draft generation remains preview-only unless the existing Frontend Assistant write gate is used directly.
- Execute: can only hand off to existing safe flows such as Test Workbench and Localnet after approval. The agent does not create raw commands.
- Chain-write: can only hand off to existing Program Manager localnet/devnet gates after approval. Mainnet writes remain locked.

The registry includes:

- `project.scanBrain`
- `project.getBrain`
- `idl.list`
- `idl.diff`
- `account.decode`
- `pda.derive`
- `transaction.debug`
- `logs.parse`
- `rpc.safeRead`
- `localnet.status`
- `localnet.startExistingSafeFlow`
- `test.detect`
- `test.runExistingSafeFlow`
- `compute.record`
- `program.preflight`
- `program.deployExistingSafeFlow`
- `security.scan`
- `frontend.inspect`
- `frontend.generateDraft`

The Workstation Agent stores redacted tool-call history under Developer Workstation Application Support evidence. It cannot run raw commands, call arbitrary RPC, broadcast transactions, deploy to mainnet, or export developer wallet secret material.

### Test Workbench boundary

Test Workbench can read untrusted project files to detect test frameworks, but it cannot execute tests until the project is explicitly trusted.

- supported fixed commands:
  - `anchor test --provider.cluster http://127.0.0.1:8899`
  - `cargo test`
- no command runs automatically after detection
- run controls require a fixed command preview and the exact approval phrase
- stdout and stderr are bounded and redacted before evidence storage
- package scripts, arbitrary terminal input, arbitrary flags, custom npm scripts, and mainnet writes are not available
- native Solana projects map to `cargo test`; `cargo build-sbf` remains unsupported until a reviewed fixed builder is added
- LiteSVM, Mollusk, and Trident are detected from dependencies/config only and remain unsupported if no reviewed builder is present

Missing-test suggestions are deterministic Project Brain analysis only. They do not use AI and they do not write test files automatically. If the user explicitly clicks to create a draft, GORKH writes a marked draft under Application Support `GORKH/DeveloperWorkstation/test-drafts/`, never into the project tree, and never overwrites an existing file. If the selected framework has no reviewed fixed builder, the draft is copy-only.

### Compute Regression boundary

Compute Regression stores metadata from real logs only:

- compute units parsed from `Program ... consumed X of Y compute units`
- compute units parsed from explicit `units consumed:` or `compute units:` lines
- source labels: Compute Lab, Transaction Debugger, or Test Output
- project id, instruction label, evidence id/signature when available, timestamp, and bounded log summary

Users can select a baseline only from an existing measurement. Regression rows compare latest measurement against that selected baseline and report improved, stable, regressed, or no baseline.

### Project Brain scanning boundary

Project Brain is allowed for untrusted projects because it only reads bounded files and never executes code.

- scans local folder projects only; zip imports stay metadata-only until extracted by a reviewed safe flow
- does not run `cargo`, `npm`, `anchor`, `solana`, package scripts, build scripts, or project binaries
- skips symlinks, heavy dependency/build directories, and files outside the project root
- bounds file count and file size
- reads `Anchor.toml`, `Cargo.toml`, `package.json`, Rust source files, `idl/*.json`, `target/idl/*.json`, `target/types/*`, tests, and deploy artifact metadata
- treats `Anchor.toml` and `package.json` scripts as text metadata only
- stores Project Brain reports as redacted JSON under the Developer Workstation Application Support evidence path

The scan reports mismatches honestly instead of guessing, including `declare_id!` vs `Anchor.toml`, `declare_id!` vs IDL address, missing local IDLs, IDLs without matching source programs, stale generated TypeScript clients, missing Anchor tests, and possible JavaScript `number` use for large integer IDL args.

### Transaction Debugger read-only boundary

Transaction Debugger is a chain-inspection tool, not an execution surface.

- allowed RPC from this page: `getTransaction`, bounded account info after an explicit account-detail request, and status lookups when wired through reviewed code
- blocked from this page: transaction submission, airdrops, broad account scans, custom RPC text, shell commands, signing, and broadcasting
- mainnet can be inspected only through read-only transaction fetches when configured RPC policy allows it
- logs are bounded and redacted before evidence storage
- raw transaction payloads and RPC secrets are not persisted
- account owner, lamports, executable state, and token account details are fetched only after the user explicitly asks for account details
- IDL error mappings are exact-code matches only; unmapped custom errors stay unmapped
- PDA checks are deterministic only when concrete IDL seed metadata is available; dynamic seeds are reported as possible causes rather than facts

### PDA Explorer boundary

PDA Explorer uses the app's existing Solana program-derived-address utility for SHA-256 PDA creation and ed25519 off-curve validation.

- manual seed inputs are converted to bytes explicitly and each seed is capped at the Solana 32-byte limit
- derivation never touches a wallet and never signs
- optional account existence checks use read-only `getAccountInfo` only
- account checks show owner, owner label, lamports, executable flag, data length, and an Anchor account type match when a loaded IDL discriminator matches
- PDA mismatch warnings are deterministic only when every required seed value is known
- no broad account scans are used

### Security Scanner boundary

Security Scanner is deterministic and read-only. It does not run project code, execute package scripts, call external services, or claim full audit coverage.

The scanner uses bounded reads of Rust and TypeScript/JavaScript source plus loaded IDL, Project Brain, and release evidence when available. It emits conservative findings with source file, line, evidence, confidence, and suggested fix for:

- unchecked `AccountInfo` / `UncheckedAccount` patterns with weak owner/address/seed validation indicators
- PDA seed constraints missing nearby bump usage
- token account fields missing obvious `token::mint` / `token::authority` constraints
- authority-sensitive accounts that are not obviously signers
- possible missing `has_one` relationships
- unchecked arithmetic, narrowing casts, and floating point usage in on-chain Rust
- CPI calls with weak program validation indicators
- `init` / `close` patterns that need manual review
- release artifacts without release hashes and release records missing upgrade-authority metadata
- TypeScript `number` usage for IDL `u64` / `u128`-like args
- hardcoded client program ids that drift from IDL/Project Brain metadata

Every finding is framed as a potential issue unless deterministic. Findings can be dismissed with a reason, and scanner reports can be exported as redacted JSON. Scanner output is a review aid, not a professional audit.

### Frontend Assistant boundary

Frontend Assistant is a native SwiftUI project-inspection and draft-generation tool for full-stack Solana apps. It does not install packages, run package scripts, execute frontend code, or broadcast transactions.

The assistant reads bounded `package.json`, TypeScript, JavaScript, and JSON files from the active imported project and uses Project Brain plus the loaded IDL to detect:

- Next.js, Vite, React, Anchor, web3.js, Solana Kit, and wallet-adapter signals
- generated clients and IDL imports
- hardcoded program IDs and cluster hints
- frontend program ID drift against `Anchor.toml`, IDL metadata/address, and Project Brain program ids
- TypeScript `number` use for IDL `u64`, `u128`, `i64`, and `i128` arguments
- obviously invalid public key strings in frontend PublicKey/program contexts
- transaction-builder code that may be missing a wallet/signer guard

Generation is preview-first and approval-gated. It can draft:

- TypeScript PDA helpers from Project Brain PDA candidates
- instruction account-map skeletons from IDL account metadata
- React hook drafts for selected instructions
- program constants files
- IDL import wrappers

Generated code separates build/send responsibilities, avoids fake wallet APIs, uses `bigint` for large integer IDL args, and never includes secrets. The Write action requires the exact phrase `Write generated frontend draft`, writes only under `gorkh/frontend-assistant/`, and blocks overwriting existing files unless a future reviewed overwrite gate explicitly allows it.

Evidence stores selected instruction, generated file path summaries, payload mode, and write/blocked status as redacted JSON. It does not store full source exports, private paths, private keys, seed phrases, wallet JSON, RPC secrets, package-manager output, or command environments.

## IDL and Account Decode

D2/D3 deepen IDL parsing by showing instruction accounts, signer/writable counts, account discriminators, types, events, errors, and local IDL drift.

The account decoder can match Anchor account discriminators and decode bounded Anchor/Borsh fields:

- bool
- signed and unsigned 8/16/32/64-bit integers
- string with a bounded length
- pubkey
- vectors of supported primitive fields with a bounded maximum length
- options of supported primitive fields
- fixed arrays of supported primitive fields when length is known
- nested structs from IDL types with bounded recursion depth

Maps, arbitrary generics, recursive unknown types, oversized vectors, malformed data, and unknown custom layouts fall back to an honest unavailable state.

## Offline Signing Foundation

Offline signing is a foundation only. It can describe and prepare future unsigned/signed file review workflows, but it does not sign or broadcast.
