# Developer Workstation Smoke

Use this checklist for Developer Workstation local QA. Do not run untrusted project commands.

## App Navigation

- Open GORKH.
- Confirm top-level navigation shows Developer Workstation.
- Open Developer Workstation.
- Confirm sections are visible: Overview, Project Brain, Transaction Debugger, PDA Explorer, IDL Drift, Fixture Studio, Test Workbench, Compute Regression, Release Manager, Security Scanner, Frontend Assistant, Workstation Agent, Projects, Toolchain, IDL Browser, Program Manager, Logs, Account Decoder, RPC Playground, Compute Lab, Localnet, Offline Signing, Activity.

## Workstation 2.0 Intelligence

- Open Project Brain with no imported project.
- Expected: honest unavailable state with no fabricated project summary.
- Import an Anchor folder project.
- Expected: Project Brain shows a Rescan Project button, read-only badge, trust badge, and no execution controls.
- Click Rescan Project.
- Expected: scan completes without running cargo, npm, Anchor, Solana CLI, package scripts, or project binaries.
- Expected: Project Brain shows real detected programs, IDLs, instructions, account types, PDA candidates, clients/frontends, tests, warnings, and unsupported findings from project files.
- Expected: Program ID mismatches between `declare_id!`, `Anchor.toml`, and IDL metadata are shown as high severity warnings when present.
- Expected: reports are stored as redacted JSON with relative/summarized paths only.
- Open an IDL entry from Project Brain.
- Expected: IDL Browser receives the exact local IDL file when it is inside the active project and under the scan size limit.
- Open Account Decoder or PDA Explorer from Project Brain actions.
- Expected: handoff changes section only; it does not fetch chain state or run commands by itself.
- Open Transaction Debugger with a public signature.
- Expected: UI shows selected cluster, optional IDL/project context, read-only badge, and Fetch & Debug.
- Click Fetch & Debug.
- Expected: the page uses read-only `getTransaction` only, then shows status, slot/block time, fee, programs, instruction tree, bounded logs, account table, compute lines, error mapping, PDA checks, and redacted evidence.
- Expected: failed Anchor transactions show `AnchorError occurred`, `Error Code`, `Error Number`, and `Error Message` when those lines are present.
- Expected: custom program errors such as `custom program error: 0x...` are converted to decimal and mapped to loaded IDL errors only when the IDL contains that exact code.
- Expected: unmapped custom errors are labeled honestly as unmapped.
- Expected: account owner/lamports/token details remain absent until Fetch Account Details is clicked.
- Click Fetch Account Details.
- Expected: the page uses bounded read-only account info for at most 20 transaction accounts.
- Expected: no signing, broadcast, write RPC, raw terminal, or command-runner controls appear.
- Open PDA Explorer with an IDL that has PDA seed metadata.
- Expected: constant-seed PDAs derive only with a concrete program id; dynamic seed PDAs show unavailable reason instead of guessed addresses.
- Enter a manual program id and PDA seeds using UTF-8, pubkey, raw hex, byte-list, and little-endian integer seed rows.
- Expected: derivation produces a real PDA and bump or an exact invalid-input reason; no signing or command execution occurs.
- Click Check Account Existence for a derived PDA.
- Expected: only read-only `getAccountInfo` is used, with owner, lamports, executable flag, data length, and optional IDL account type match.
- Open the IDL Browser Drift panel and compare two local IDLs for the same program area.
- Expected: program id, instruction, account, field, error, event, discriminator, or generated-client staleness differences are shown from real local files only.
- Expected: on-chain IDL drift is marked unsupported unless a reviewed read-only fetcher is available.
- Open Security Scanner.
- Expected: findings are derived from imported metadata, trust state, selected cluster, and toolchain state.
- Open Test Workbench.
- Expected: detection can run for untrusted projects because it only reads files.
- Expected: Anchor/Cargo/native Solana frameworks are detected from `Anchor.toml`, `Cargo.toml`, and test files.
- Expected: LiteSVM/Mollusk/Trident dependencies are detected but marked unsupported unless a reviewed fixed builder exists.
- Try to prepare a test command while the project is untrusted.
- Expected: blocked with a trust warning.
- Trust the project and prepare an Anchor or Cargo command.
- Expected: command preview is fixed (`anchor test --provider.cluster http://127.0.0.1:8899` or `cargo test`), with no raw terminal input, no arbitrary flags, and no package script picker.
- Try to run without the exact approval phrase.
- Expected: blocked.
- Run only when intentionally testing a trusted local project.
- Expected: stdout/stderr are bounded and redacted before evidence storage.
- Create a missing-test draft from a Project Brain suggestion.
- Expected: draft creation happens only after the click, writes under Application Support `GORKH/DeveloperWorkstation/test-drafts/`, is marked as a draft, does not overwrite files, and does not add a file to the imported project.
- Open Compute Regression.
- Expected: measurements can be stored only from real Transaction Debugger, Compute Lab, or Test Workbench logs.
- Expected: baseline selection is available only from an existing stored measurement.
- Open Frontend Assistant.
- Expected: page shows native SwiftUI safety badges for read-only inspection, preview-first generation, no package installs, no script execution, and scoped draft writes.
- Click Inspect Frontend with an imported project selected.
- Expected: scan reads bounded frontend files only and detects package.json, framework hints, generated clients, IDL imports, hardcoded program IDs, cluster hints, u64/u128 number usage, invalid public key strings, and possible missing wallet/signer guards from real files.
- Expected: no npm, pnpm, yarn, package script, shell, RPC write, signing, or broadcast operation runs.
- Select an IDL instruction and preview each draft kind: PDA helper, account map, React hook, constants file, and IDL import wrapper.
- Expected: generated code appears as preview only, uses `bigint` for large integer IDL args, avoids fake wallet APIs, separates build/send responsibilities, and includes no secrets.
- Try Write Approved Drafts without the exact phrase.
- Expected: write is blocked.
- Enter `Write generated frontend draft` and write to a fresh project draft path only when intentionally testing file output.
- Expected: files are written under `gorkh/frontend-assistant/`, existing files are not overwritten, and redacted evidence stores only path summaries and write status.
- Expected: evidence contains no full private project root, private key, seed phrase, wallet JSON, RPC secret, or unredacted source export.
- Open Workstation Agent.
- Expected: page states this is not the global Agent and that AI chat is unavailable when no provider is configured.
- Select Read-only mode and run `project.getBrain`, `idl.list`, `localnet.status`, or `rpc.safeRead` with available context.
- Expected: tool calls return deterministic summaries from existing Workstation state and store redacted history.
- Select Execute mode and choose `test.runExistingSafeFlow` without approval.
- Expected: approval card blocks the tool and shows the required Developer Agent approval phrase.
- Enter the approval phrase.
- Expected: the agent delegates to the existing Test Workbench safe flow; it does not execute project code directly from chat.
- Select Chain-write mode and choose `program.deployExistingSafeFlow` on mainnet.
- Expected: mainnet write is blocked.
- Select localnet/devnet with a trusted project.
- Expected: the agent can only hand off to existing Program Manager gates and does not bypass command preview or destructive phrases.
- Expected: raw command, raw terminal, arbitrary RPC, transaction broadcast, mainnet deploy, and secret export tools are always blocked.

## Project Import

- Inspect an absolute local folder path.
- Expected: project imports as untrusted.
- Expected: detected framework and file counts appear if Anchor/Cargo/package files exist.
- Prepare an HTTPS Git URL.
- Expected: fixed git clone plan is prepared, but no command runs automatically.

## Trust Gate

- Try Program Manager with untrusted project.
- Expected: build/deploy operations are blocked.
- Enter the exact trust phrase.
- Expected: trust state changes to Trusted.

## Toolchain

- Click Check Toolchain.
- Expected: Solana CLI, AVM, Anchor, Rust, Cargo, Node, npm, and Git show available/missing states honestly.
- Expected: managed install plan appears for each tool.
- Expected: archive manifest entries are blocked until verified source and sha256 are filled.
- Expected: Anchor/AVM wizard shows detected Anchor, detected AVM, Cargo-backed AVM install plan, or Cargo missing blocker.
- Expected: bundled availability is not claimed unless app resources contain binaries.
- Missing tools should disable dependent program operations.

## IDL Browser

- Paste a small Anchor IDL fixture.
- Expected: instructions, accounts, types, errors, and events parse if present.
- Expected: instruction signer/writable counts and account discriminators are visible.
- Search for an instruction or account field.
- Expected: filtered rows update without running code.
- Invalid JSON should show a parse failure activity event.

## Account Decoder

- Enter a public account address and optional safe base64 fixture data.
- Expected: owner/data summary appears when available.
- If an Anchor discriminator and bounded fields match the loaded IDL, expected primitive, vector, option, fixed-array, and nested-struct values are shown.
- If maps, unknown generics, recursive unknown types, oversized vectors, malformed data, or unknown custom layouts are present, expected state is partial/unavailable rather than guessed.

## Logs

- Enter a valid program id.
- Start and stop log stream.
- Expected: bounded buffer and redacted lines.

## RPC Playground

- Select read-only methods such as `getHealth`, `getVersion`, `getBalance`, and `simulateTransaction`.
- Expected: required fields are validated.
- Select `sendTransaction`.
- Expected: blocked.
- Select broad `getProgramAccounts`.
- Expected: blocked.
- Select custom method.
- Expected: blocked.

## Faucet

- Select localnet or devnet.
- Enter a valid public key and a small amount.
- Expected: faucet request is allowed through faucet guard only.
- Select mainnet.
- Expected: blocked.

## Local Validator

- Check Localnet.
- Expected: local validator status and fixed start-command preview are visible when `solana-test-validator` is discoverable.
- Expected: reset ledger requires `Reset local validator ledger`.
- Expected: external validators are not stopped by GORKH.
- Expected: logs are bounded and redacted.
- Do not reset the ledger unless explicitly testing destructive localnet behavior.

## Sample Localnet Smoke

- Open Program Manager.
- Run Sample Localnet Smoke Preflight.
- Expected: preflight lists fixed steps and blockers.
- Expected: Anchor missing blocks live sample build/deploy.
- Expected: no live action runs automatically from preflight.

## Deployment Release Manager

- Open Program Manager -> Build / Deploy.
- Expected: existing fixed command preview flow remains available and no command runs automatically.
- Open Upgrade Preview.
- Expected: upgrade requires localnet/devnet, program id, artifact path, fixed command preview, and exact upgrade phrase.
- Open Authority Preview.
- Expected: transfer/revoke authority previews use fixed builders and destructive phrases; mainnet remains locked.
- Open Preflight Checks before preparing a command preview.
- Expected: fixed command preview and explicit approval checks are blocked.
- Prepare a valid localnet/devnet command preview and run preflight.
- Expected: trust, cluster, toolchain, developer wallet, program id consistency, artifact, IDL, drift, upgrade authority, balance, temp keypair, fixed preview, and approval rows are visible.
- Create a release record from real deploy evidence.
- Expected: record includes public program id/signature, tool versions, command summary, artifact hash if available, IDL hash if available, and no full private paths.
- Copy latest release JSON.
- Expected: exported JSON is redacted and contains no private key, seed phrase, wallet JSON, temp keypair contents, or unredacted command environment.

## Security Scanner

- Import a folder project.
- Open Security Scanner.
- Expected: page shows read-only, no external services, and not-a-full-audit badges.
- Run Scan.
- Expected: scanner reads bounded source files only and does not run Cargo, Anchor, Solana CLI, npm, package scripts, RPC writes, or external API calls.
- Expected: findings, if present, include severity, confidence, category, source relative path/line, evidence, and suggested fix.
- Verify conservative categories:
  - unchecked `AccountInfo` / `UncheckedAccount`
  - weak token/account constraints
  - unchecked arithmetic or floating point
  - CPI validation indicators
  - release evidence/hash gaps
  - TypeScript `number` for IDL `u64` / `u128`-like args
- Filter findings by severity/status/text.
- Dismiss one finding with a reason.
- Expected: finding status changes to dismissed and reason is redacted.
- Copy redacted scanner report.
- Expected: exported JSON contains no full private project root, private key, seed phrase, wallet JSON, temp keypair contents, or command environment.

## Compute Lab

- Confirm compute lab states simulation-only and does not sign or broadcast.
- Confirm Compute Regression is visible from Compute Lab.
- Confirm no baseline exists until a real compute-unit log measurement is stored.
- Confirm selecting a baseline uses an existing measurement and never creates a fake value.

## Offline Signing

- Confirm offline signing is foundation-only and cannot sign or broadcast.

## Activity

- Confirm Workstation activity records imports, trust, toolchain checks, log start/stop, and blocked commands without sensitive data.
