# Cloak Bridge Invocation

Phase 2.5 keeps the helper behind the fixed native bridge and enables only reviewed Cloak SOL deposit/full-withdraw execution. All other Cloak execution paths remain locked.

## Allowed Commands

Dry-run commands remain allowed:

- `health`
- `env-check`
- `deposit-plan`

Execution commands allowed only through the interactive native signer bridge:

- `execute-deposit`
- `full-withdraw`

All other transaction or history commands remain locked:

- `partial-withdraw`
- `private-transfer`
- `swap`
- `scan`
- `compliance-export`

## Process Boundary

The adapter uses direct process invocation only. It must not use `/bin/sh`, `sh -c`, or user-provided command strings.

The helper path is fixed:

- `tools/cloak-bridge/src/index.ts`

The executable path must resolve to one of the allowlisted Node paths:

- `/opt/homebrew/bin/node`
- `/usr/local/bin/node`
- `/usr/bin/node`

No arbitrary executable path or helper path is accepted.

## Data Boundary

Swift validates requests before invocation, validates every signing request from the helper, and validates final responses. The helper also validates input before handling commands.

Forbidden fields include private keys, secret keys, signing seeds, seed phrases, mnemonics, wallet JSON, UTXO private keys, notes, viewing keys, nullifiers, proof inputs, serialized transactions, transaction payloads, transaction bytes, message bytes, raw messages, raw transactions, and raw signer bytes.

## SDK Validation and Execution

The helper may import `@cloak.dev/sdk` for validation:

- SDK import/package version
- `CLOAK_PROGRAM_ID`
- `NATIVE_SOL_MINT`
- SDK SOL fee helpers, if exported

For Phase 2.5 execution, the helper may call only:

- `generateUtxoKeypair`
- `createUtxo`
- `createZeroUtxo`
- `transact`
- `fullWithdraw`
- `serializeUtxo`
- `deserializeUtxo`
- `getNkFromUtxoPrivateKey`
- SDK parsing helpers for safe errors

The helper must not call private transfer, swap, partial withdraw, scan, compliance export, relay submit, or any method that signs directly in TypeScript.

## Signer Bridge Summary

`deposit-plan` may return a `signerRequestSummary` in locked mode. The summary is a review contract only and may contain safe fields such as public wallet address, network, amount lamports, mint, program id, fee quote, human-readable purpose, and draft fingerprint.

The helper must not return transaction bytes, message bytes, serialized transaction payloads, or any field that could be signed directly. Swift validates the summary before showing it in Wallet -> Private.

## Execution State

`deposit-plan` returns SDK validation, environment-safe fee validation, a fee quote, a locked signer request summary, and locked status only. It does not return a serialized transaction, signer bytes, SDK payload, proof input, note, UTXO, message bytes, transaction bytes, or executable instruction.

`execute-deposit` and `full-withdraw` are line-framed interactive commands. They may emit signing requests with payload bytes only over stdin/stdout during the approved operation. Final responses include safe summaries plus secure state blobs for Swift Keychain storage. Those secure state blobs must not be logged, audited, stored in UserDefaults, or sent to Agent/Assistant context.

The helper process receives no secret environment. Until a header-safe RPC proxy is added for RPC Fast authentication, the Cloak helper uses a public mainnet RPC URL for SDK execution rather than receiving RPC provider tokens.
