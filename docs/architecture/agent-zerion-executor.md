# Agent Zerion Executor

Phase A1 added the top-level Agent section and Zerion Executor foundation. Phase A2 adds one tightly scoped execution path: an explicitly approved tiny same-chain Zerion swap from a separate Zerion wallet.

## Source Guidance

Reviewed guidance:

- Zerion CLI repository guidance provided for `zerion-cli`.
- Zerion API docs for API-key setup and HTTP Basic Auth.
- Zerion CLI command summary provided for wallet, portfolio, position, history, PnL, and agent policy/token commands.
- Local `zerion-docs.md` in Downloads, which confirms Node.js 20+, `ZERION_API_KEY`, JSON stdout, structured JSON stderr, manual wallet/policy/token setup, and conflicting swap command examples that require runtime help probing.

## Safety Boundary

GORKH Agent can observe, summarize, draft, and hand off. It cannot use the GORKH main wallet. In A2, only an explicitly approved tiny Zerion swap can execute through the separate Zerion wallet and scoped Zerion policy.

Hard boundaries:

- Zerion wallet must be separate from the GORKH wallet.
- Zerion agent wallet should be tiny-funded only.
- GORKH never passes Keychain signer material, recovery text, private keys, wallet files, or Cloak private vault data to Zerion.
- Zerion API key and agent token are environment/config secrets and are never stored in UserDefaults, audit logs, snapshots, or UI.
- Agent tokens are treated as spending power.
- A2 allows one policy-validated tiny same-chain Zerion swap only.
- Bridge, send, signing, recurring automation, wallet import, and GORKH main-wallet execution remain blocked.

## CLI Detection

`ZerionCLIPathResolver` checks only safe executable locations:

- `/opt/homebrew/bin/zerion`
- `/usr/local/bin/zerion`
- absolute executable paths resolved from `PATH`

The resolver rejects relative paths, traversal, command separators, and executables not named `zerion`. There is no user-supplied executable path in A1.

## Command Allowlist

A1 allows read/status Zerion CLI commands only.

A1 allows only read/status commands:

- `zerion --help`
- `zerion chains`
- `zerion wallet list`
- `zerion agent list-policies`
- `zerion agent list-tokens`
- `zerion config list`
- `zerion portfolio <address>`
- `zerion positions <address>`
- `zerion history <address>`
- `zerion pnl <address>`

Portfolio, positions, history, and PnL reads require `ZERION_API_KEY` to be present and correctly shaped. The key is checked only as present/missing/malformed and is redacted.

Blocked in A1:

- trading commands
- signing commands
- wallet create/import/fund/backup/delete/sync
- policy/token creation or revocation
- arbitrary command input
- command interpreter execution

A2 adds only a typed tiny-swap command builder. Raw command parsing still rejects `swap`, `bridge`, `send`, `sign-message`, and `sign-typed-data`. The execution path builds arguments internally after policy validation and never accepts arbitrary flags or command text from the UI.

## CLI Help Probe

A2 probes:

- `zerion --help`
- `zerion swap --help`
- `zerion agent --help`
- Node.js `--version`, when discoverable

The swap command is executable only if local help clearly validates one supported shape:

- `zerion swap <chain> <amount> <from-token> <to-token>`
- `zerion swap <from> <to> <amount> --chain <chain>`

If help is unavailable or ambiguous, live execution remains locked with a clear blocker.

## Process Runner

`ZerionCLICommandRunner` uses `Process` with an exact executable URL and argument array. It captures stdout/stderr, applies redaction, and normalizes success, failure, timeout, and blocked states. It does not accept raw command strings.

## UI

The Agent section contains:

- Overview
- Zerion Executor
- Policy Center
- Proposals
- Audit

The Zerion Executor shows CLI status, API key status, token status, policy status, wallet count, supported chains, last check time, and safe errors. Policy Center reads policy/token status when the CLI is configured. Legacy proposals remain draft-only; A2 adds a separate tiny-swap proposal type with a guarded execution flow.

## Proposal Model

Legacy draft proposals cannot execute or sign.

`ZerionProposal` supports future swap, bridge, send, rebalance, and DCA proposals, but those general proposal types stay draft-only. They cannot execute or sign in A2.

`ZerionTinySwapProposal` is the A2 execution proposal. It supports only:

- Solana `SOL -> USDC`, tiny amount
- Base `USDC -> ETH`, tiny amount

Required before execution:

- separate Zerion wallet name,
- matching scoped policy,
- agent token present,
- `ZERION_API_KEY` present and redacted,
- local notional below the tiny cap,
- fresh proposal fingerprint,
- exact confirmation phrase.

The required phrase is:

`I understand this uses a separate Zerion wallet and executes a real onchain transaction.`

## Audit

Agent/Zerion audit events are safe local timeline entries:

- Agent section viewed
- Zerion CLI status checked
- API key status checked
- wallet list checked
- policies checked
- tokens checked
- proposal drafted
- proposal approved
- execution started
- execution succeeded
- execution failed
- policy validation failed
- command blocked
- command failed

Details are redacted and must not contain API keys, agent tokens, wallet secrets, or raw command payloads.

## Live Smoke Boundary

Do not run a live Zerion swap unless all of the following are true:

- separate Zerion wallet exists,
- scoped policy exists,
- agent token is configured and treated as spending power,
- status is visible in GORKH,
- CLI swap help validates the command shape,
- the exact approval phrase is entered,
- amount is intentionally tiny,
- no GORKH main-wallet secret path exists.
