# Cloak Signer Bridge

Phase 2.4 defines the native signer bridge review flow for future Cloak deposits. It does not sign Cloak transactions, does not call Cloak transaction APIs, and does not create serialized transaction or message payloads.

## Boundary

The TypeScript Cloak helper never receives wallet signing material. It may return safe request summaries only:

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
- locked state

The helper must not receive or return:

- wallet private key
- signing seed
- seed phrase
- mnemonic
- wallet JSON
- full raw transaction bytes
- serialized transaction
- message bytes
- UTXO private key
- full UTXO
- note secret
- viewing key
- nullifier
- proof input

## Native Signing Authority

Swift native wallet code remains the only signing authority. Future `signTransaction` or `signMessage` support must use scoped native approval and must never give the helper direct key access.

Future signing requires:

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

In Phase 2.4 the policy evaluates summaries and always returns locked for actual signing.

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

Steps 7 and 8 are locked in Phase 2.4. A future tiny mainnet deposit phase must separately implement reviewed payload handling, native signing, SDK execution, confirmation, and audit.

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
