# Zerion Agent End-To-End Smoke

This checklist validates the Agent + Zerion hackathon demo path. It is manual because it can execute a real tiny transaction from a separate Zerion wallet.

Do not run this with the GORKH main wallet. Do not commit keys, agent tokens, local environment values, wallet files, screenshots with secrets, or terminal history containing secrets.

## Preconditions

- Node.js 20 or later is installed.
- Zerion CLI is installed.
- Zerion API key is set only in the local terminal.
- A separate tiny-funded Zerion wallet exists.
- A scoped policy exists for `solana` or `base`.
- An agent token exists for that policy and wallet.
- The token value is not displayed or logged.

## Status Checklist

1. Open GORKH -> Agent -> Zerion Executor.
2. Refresh status.
3. Confirm CLI is installed.
4. Confirm Node.js is version 20 or later.
5. Confirm API key status is present-redacted.
6. Confirm separate Zerion wallet count/default wallet is visible if CLI returns it.
7. Confirm policy status is loaded.
8. Confirm agent token status is present-redacted.
9. Confirm swap help status is loaded and command shape is validated.
10. Confirm no GORKH main-wallet access is shown.

## Proposal Checklist

1. Open Agent -> Chat.
2. Enter a tiny Zerion swap request.
3. Confirm the Agent creates a proposal, not an execution.
4. Confirm the proposal lane is Zerion.
5. Confirm policy check passed or blockers are clearly listed.
6. Open Agent -> Proposals.
7. Open the tiny swap review.

## Review Checklist

Confirm the review screen shows:

- separate Zerion wallet,
- chain,
- amount,
- from token,
- to token,
- scoped policy,
- local tiny cap,
- redacted command preview,
- exact confirmation phrase,
- no GORKH main-wallet signer.

Execution must remain blocked until:

- all blockers are gone,
- unknown USD value is acknowledged if needed,
- the exact phrase is entered.

## Execution Checklist

1. Execute only after review is clean.
2. Capture transaction hash/signature and chain.
3. Confirm the result appears in Agent -> Audit.
4. Confirm the audit timeline includes proposal created, policy decision, approval, execution started, and execution result.
5. Confirm audit details contain no secrets.

## Cleanup

1. Revoke the agent token.
2. Confirm the policy expires soon or revoke it.
3. Remove the local API key from the terminal session.
4. Keep the separate Zerion wallet tiny-funded only.

## Evidence

Record:

- status screenshot with redacted key/token states,
- proposal/review screenshot,
- transaction hash/signature,
- audit screenshot,
- cleanup confirmation.

If no live transaction is run, mark the live step as pending and do not claim it in the submission.

## A8 Rehearsal Result - 2026-05-10

Status: blocked before live transaction.

Validated locally:

- Node.js status: installed, `v22.22.2`.
- Zerion CLI status: not resolved in PATH.
- Zerion API key status: missing in the shell environment, checked without printing a value.
- Separate Zerion wallet: not verified because CLI/API setup is incomplete.
- Scoped policy: not verified because CLI/API setup is incomplete.
- Agent token: not verified because CLI/API setup is incomplete.
- Proposal/review/execution: not run live because the required Zerion prerequisites are missing.

Evidence status:

- Transaction hash/signature: pending.
- Audit timeline for live execution: pending.
- Cleanup/revoke: pending; no token was created or used during this rehearsal.

Blocker:

Install/configure Zerion CLI, set `ZERION_API_KEY` locally, create a separate tiny-funded Zerion wallet, create a scoped policy, and create an agent token. Then rerun this checklist before claiming a live transaction.
