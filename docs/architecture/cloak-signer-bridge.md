# Cloak Signer Bridge

Phase 2.5 enables the native signer bridge for the Cloak SOL private payment MVP. It supports reviewed mainnet-only Shield SOL deposits and full-withdraw/private pay flows. Private swap, partial withdraw, batch payroll, scans, and compliance export remain locked.

## Boundary

The TypeScript Cloak helper never receives wallet signing material. For dry-run commands it may return safe request summaries only:

- request id
- request kind
- wallet public key
- network
- Cloak action kind
- amount lamports
- mint address
- Cloak program id
- fee quote
- human-readable purpose
- draft fingerprint
- locked or reviewed state

For approved execution commands, the helper may emit transient JSON-framed signing requests to Swift:

- request id
- signing kind
- wallet public key
- network
- action kind
- amount lamports
- mint address
- Cloak program id
- draft fingerprint
- human-readable purpose
- unsigned transaction/message payload, base64, in memory only

The transient payload is validated, signed by Swift, returned to the helper, and never persisted, logged, audited, or exposed to Agent/Assistant context.

The helper must not receive or return:

- wallet private key
- signing seed
- seed phrase
- mnemonic
- wallet JSON
- full raw transaction bytes in persistent state, logs, audit, or UI
- serialized transaction in persistent state, logs, audit, or UI
- message bytes in persistent state, logs, audit, or UI
- UTXO private key
- full UTXO
- note secret
- viewing key
- nullifier
- proof input

## Native Signing Authority

Swift native wallet code remains the only signing authority. Future `signTransaction` or `signMessage` support must use scoped native approval and must never give the helper direct key access.

Signing requires:

- wallet unlocked
- LocalAuthentication success
- signer public key matches the selected wallet
- network matches the approved draft
- Cloak action kind matches the approved draft
- amount matches the approved draft
- Cloak program id matches `zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW`
- fee quote acknowledged
- Shield review completed
- explicit user approval
- exact mainnet confirmation phrase on mainnet
- draft fingerprint matches the signing request
- audit event before signing
- audit event after signing

The Phase 2.5 policy enables signing only for `execute-deposit` and `full-withdraw`. Partial withdraw, private transfer, swap, scan, and compliance export remain locked.

## Review Flow

The Wallet -> Private flow is:

1. Deposit draft
2. Fee and minimum check
3. SDK and environment validation
4. Signer preflight
5. Shield review
6. Explicit approval
7. Local signing
8. Cloak SDK execution
9. Audit

Steps 7 and 8 are live only for the MVP actions after explicit approval. Live mainnet smoke remains manual and must never run automatically.

## Fingerprint

The signer request summary includes a draft fingerprint over safe fields:

- wallet public key
- network
- action kind
- amount lamports
- mint address
- Cloak program id
- fee quote gross, fee, and net lamports

The fingerprint is a review integrity check. It is not a secret and must not be used as authorization by itself.

## Audit

Audit events may record safe summaries:

- request id
- signer state
- network
- action kind
- amount lamports
- mint address
- draft fingerprint
- requirement count

Audit events must not contain wallet secrets, Cloak private material, transaction bytes, message bytes, or proof inputs.

## Private State

Confirmed deposits return serialized Cloak UTXO state to Swift for local vault storage. Deposits shield the full positive `externalAmount`; the fixed and variable fee model is shown for SOL withdraw/send paths. The spend state and viewing key material are stored in Keychain only. Safe metadata outside Keychain is limited to record id, wallet id, public wallet address, mint, amount, commitment prefix, leaf index, signature, timestamp, request id, and state.

If a future SDK path requires TypeScript to reconstruct a UTXO object, Swift may pass the stored spend state back to the helper only transiently for the already approved request. The helper must not log or persist that state.
