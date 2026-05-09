# Cloak Bridge Invocation

Phase 2.4 keeps native invocation disabled by default, validates SDK import and environment state, and adds locked signer request summaries without executing SDK transaction methods.

## Allowed Commands

Only dry-run commands are allowed:

- `health`
- `env-check`
- `deposit-plan`

All transaction or history commands remain locked:

- `execute-deposit`
- `full-withdraw`
- `partial-withdraw`
- `private-transfer`
- `swap`
- `scan`
- `compliance-export`

## Process Boundary

The adapter uses direct process invocation only when an internal development policy enables it. It must not use `/bin/sh`, `sh -c`, or user-provided command strings.

The helper path is fixed:

- `tools/cloak-bridge/src/index.ts`

The executable path must resolve to one of the allowlisted Node paths:

- `/opt/homebrew/bin/node`
- `/usr/local/bin/node`
- `/usr/bin/node`

No arbitrary executable path or helper path is accepted.

## Data Boundary

Swift validates requests before invocation and validates responses after invocation. The helper also validates input before handling commands.

Forbidden fields include private keys, secret keys, signing seeds, seed phrases, mnemonics, wallet JSON, UTXO private keys, notes, viewing keys, nullifiers, proof inputs, serialized transactions, transaction payloads, transaction bytes, message bytes, raw messages, raw transactions, and raw signer bytes.

## SDK Validation

The helper may import `@cloak.dev/sdk` for non-executing checks only:

- SDK import/package version
- `CLOAK_PROGRAM_ID`
- `NATIVE_SOL_MINT`
- SDK SOL fee helpers, if exported

The helper must not call Cloak transaction, proof, scan, compliance, relay submit, signer, or serialized-transaction APIs in Phase 2.4.

## Signer Bridge Summary

`deposit-plan` may return a `signerRequestSummary` in locked mode. The summary is a review contract only and may contain safe fields such as public wallet address, network, amount lamports, mint, program id, fee quote, human-readable purpose, and draft fingerprint.

The helper must not return transaction bytes, message bytes, serialized transaction payloads, or any field that could be signed directly. Swift validates the summary before showing it in Wallet -> Private.

## Execution State

Even when dry-run invocation is enabled, `deposit-plan` returns SDK validation, environment-safe fee validation, a fee quote, a locked signer request summary, and locked status only. It does not return a serialized transaction, signer bytes, SDK payload, proof input, note, UTXO, message bytes, transaction bytes, or executable instruction.

Future live Cloak deposit work must add a separate reviewed payload, approval, native signing, execution, confirmation, and audit phase.
