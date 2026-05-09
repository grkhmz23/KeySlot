# Cloak Bridge Invocation

Phase 2.2 adds a native invocation adapter for the local Cloak helper, but keeps it disabled by default.

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

## Execution State

Even when dry-run invocation is enabled, `deposit-plan` returns a fee quote and locked status only. It does not return a serialized transaction, signer bytes, SDK payload, proof input, note, UTXO, or executable instruction.

Future live Cloak deposit work must add a separate review, approval, signing, and audit phase.
