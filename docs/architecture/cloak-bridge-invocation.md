# Cloak Bridge Invocation

Phase 2.6 keeps the helper behind the fixed native bridge, preserves reviewed Cloak SOL deposit/full-withdraw execution, and adds one read-only scan command for private history reconciliation. No new transaction execution path is added in Phase 2.6.

## Allowed Commands

Dry-run commands remain allowed:

- `health`
- `env-check`
- `deposit-plan`

Execution commands allowed only through the interactive native signer bridge:

- `execute-deposit`
- `full-withdraw`

Read-only commands allowed through the non-interactive helper bridge:

- `scan`

All other transaction commands remain locked:

- `partial-withdraw`
- `private-transfer`
- `swap`
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

For Phase 2.5/2.6 execution, the helper may call only:

- `generateUtxoKeypair`
- `createUtxo`
- `createZeroUtxo`
- `transact`
- `fullWithdraw`
- `serializeUtxo`
- `deserializeUtxo`
- `getNkFromUtxoPrivateKey`
- SDK parsing helpers for safe errors

For Phase 2.6 read-only scan, the helper may call only:

- `scanTransactions`
- `toComplianceReport` for aggregate summary generation only

The helper must not call private transfer, swap, partial withdraw, relay submit, or any method that signs directly in TypeScript. `compliance-export` remains locked as a standalone command.

## Signer Bridge Summary

`deposit-plan` may return a `signerRequestSummary` in locked mode. The summary is a review contract only and may contain safe fields such as public wallet address, network, amount lamports, mint, program id, fee quote, human-readable purpose, and draft fingerprint.

The helper must not return transaction bytes, message bytes, serialized transaction payloads, or any field that could be signed directly. Swift validates the summary before showing it in Wallet -> Private.

## Execution State

`deposit-plan` returns SDK validation, environment-safe fee validation, a fee quote, a locked signer request summary, and locked status only. It does not return a serialized transaction, signer bytes, SDK payload, proof input, note, UTXO, message bytes, transaction bytes, or executable instruction.

`execute-deposit` and `full-withdraw` are line-framed interactive commands. They may emit signing requests with payload bytes only over stdin/stdout during the approved operation. Final responses include safe summaries plus secure state blobs for Swift Keychain storage. Those secure state blobs must not be logged, audited, stored in UserDefaults, or sent to Agent/Assistant context.

`scan` is a read-only stdin/stdout command. Swift loads the scan credential from Keychain only after wallet unlock and local authentication, passes it transiently as `scanStateBase64`, and accepts only safe scan summaries in response. The helper must not return decrypted raw payloads, full UTXOs, note contents, nullifiers, proof inputs, or the scan credential.

## RPC Routing

The helper process receives only scoped RPC Fast mainnet token environment variables:

- `GORKH_RPCFAST_MAINNET_TOKEN`
- `RPCFAST_MAINNET_TOKEN`

When one is present, the helper constructs an `@solana/web3.js` `Connection` to `https://solana-rpc.rpcfast.com/` with an `X-Token` HTTP header. It must not put tokens in query strings, stdout, stderr, audit, UI, docs, or persisted state.

If no RPC Fast token is present, env-check reports `rpcProvider: fallback`, `rpcFastTokenStatus: missing`, and the helper uses the explicit fallback RPC policy. The fallback state is visible so missing infrastructure is not silent.
