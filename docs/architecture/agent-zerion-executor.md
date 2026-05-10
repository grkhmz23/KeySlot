# Agent Zerion Executor Foundation

Phase A1 adds a new top-level Agent section and a Zerion Executor foundation. It is a no-execution phase.

## Source Guidance

Reviewed guidance:

- Zerion CLI repository guidance provided for `zerion-cli`.
- Zerion API docs for API-key setup and HTTP Basic Auth.
- Zerion CLI command summary provided for wallet, portfolio, position, history, PnL, and agent policy/token commands.

## Safety Boundary

GORKH Agent can observe, summarize, draft, and hand off. It cannot directly sign, execute, trade, or use the main wallet without explicit approval.

Hard boundaries:

- Zerion wallet must be separate from the GORKH wallet.
- Zerion agent wallet should be tiny-funded only.
- GORKH never passes Keychain signer material, recovery text, private keys, wallet files, or Cloak private vault data to Zerion.
- Zerion API key and agent token are environment/config secrets and are never stored in UserDefaults, audit logs, snapshots, or UI.
- Agent tokens are treated as spending power.
- A1 does not call Zerion trading or signing commands.

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

## Process Runner

`ZerionCLICommandRunner` uses `Process` with an exact executable URL and argument array. It captures stdout/stderr, applies redaction, and normalizes success, failure, timeout, and blocked states. It does not accept raw command strings.

## UI

The Agent section contains:

- Overview
- Zerion Executor
- Policy Center
- Proposals
- Audit

The Zerion Executor shows CLI status, API key status, token status, policy status, wallet count, supported chains, last check time, and safe errors. Policy Center reads policy/token status when the CLI is configured. Proposals are draft-only.

## Proposal Model

Draft proposals cannot execute or sign.

`ZerionProposal` supports future swap, bridge, send, rebalance, and DCA proposals, but A1 sets proposals to draft-only. A proposal cannot execute or sign in this phase.

## Audit

Agent/Zerion audit events are safe local timeline entries:

- Agent section viewed
- Zerion CLI status checked
- API key status checked
- wallet list checked
- policies checked
- tokens checked
- proposal drafted
- command blocked
- command failed

Details are redacted and must not contain API keys, agent tokens, wallet secrets, or raw command payloads.

## A2 Readiness

A2 may add one real tiny Zerion transaction only after:

- separate Zerion wallet exists,
- scoped policy exists,
- agent token is configured and treated as spending power,
- status is visible in GORKH,
- review/approval gates are designed,
- no GORKH main-wallet secret path exists.
