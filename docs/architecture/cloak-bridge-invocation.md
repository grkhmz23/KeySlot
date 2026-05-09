# Cloak Bridge Invocation

Phase 2.3 keeps native invocation disabled by default and extends the local Cloak helper to validate SDK import and environment state without executing SDK transaction methods.

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

Forbidden fields include private keys, secret keys, seed phrases, mnemonics, wallet JSON, UTXO private keys, notes, viewing keys, nullifiers, proof inputs, serialized transactions, transaction payloads, and raw signer bytes.

## SDK Validation

The helper may import `@cloak.dev/sdk` for non-executing checks only:

- SDK import/package version
- `CLOAK_PROGRAM_ID`
- `NATIVE_SOL_MINT`
- SDK SOL fee helpers, if exported

The helper must not call Cloak transaction, proof, scan, compliance, relay submit, signer, or serialized-transaction APIs in Phase 2.3.

## Execution State

Even when dry-run invocation is enabled, `deposit-plan` returns SDK validation, environment-safe fee validation, a fee quote, and locked status only. It does not return a serialized transaction, signer bytes, SDK payload, proof input, note, UTXO, or executable instruction.

Future live Cloak deposit work must add a separate review, approval, signing, and audit phase.
