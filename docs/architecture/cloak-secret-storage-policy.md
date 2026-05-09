# Cloak Secret Storage Policy

This policy defines the allowed storage and bridge boundaries for GORKH Wallet -> Private.

## Scope

Cloak integration is currently contract-only. GORKH does not execute Cloak deposits, private transfers, withdrawals, swaps, scans, or compliance exports yet.

## Secret Classes

Normal wallet secrets:

- BIP39 mnemonic
- Solana signing seed
- imported private key material
- wallet JSON / keypair arrays

Cloak-specific secrets:

- UTXO private keys
- full notes or full UTXO objects
- viewing keys / `nk`
- nullifier secrets
- proof inputs
- raw scan cache
- decrypted compliance scan contents

## Storage Rules

UserDefaults may store only public metadata and local security settings. It must never store normal wallet secrets or Cloak-specific secrets.

macOS Keychain is the only approved local storage class for wallet signing material. Future Cloak secret storage must use a Keychain-backed private vault or a vault encrypted by a Keychain-protected key.

Current Phase 2.1 private vault behavior is status-only:

- no Cloak notes are stored
- no UTXOs are stored
- no viewing keys are stored
- no nullifiers are stored
- no proof inputs are stored
- no raw scan cache is stored

## UI Rules

The UI may show:

- public wallet address
- network
- mint address
- amount lamports
- fee quote
- Cloak program id
- request id
- future transaction signature
- redacted commitment prefix
- leaf index
- bridge status

The UI must not show normal wallet secrets or Cloak-specific secrets outside a separately designed authenticated export or recovery flow.

## Logging and Audit Rules

Audit logs may include:

- action kind
- network
- public wallet address
- amount lamports
- mint address
- fee quote
- request id
- status
- future transaction signature
- redacted commitment prefix
- leaf index

Audit logs must not include:

- private keys
- seed phrases
- mnemonics
- wallet JSON
- UTXO private keys
- full UTXOs
- notes
- viewing keys
- nullifier secrets
- proof inputs
- serialized transactions
- raw signer bytes
- raw scan cache

## Bridge Rules

Swift may send only safe contract fields to the local helper:

- request id
- command
- action kind
- network
- public wallet address
- amount lamports
- mint address
- program id
- fee quote
- timestamp

Swift must not send:

- private key
- seed phrase
- mnemonic
- wallet JSON
- UTXO private key
- full UTXO object
- note secret
- viewing key
- nullifier secret
- proof input
- serialized transaction payload
- raw signer bytes

Phase 2.1 helper commands are limited to `health`, `env-check`, and `deposit-plan`. Transaction execution commands are locked.

## Scan Cache Strategy

Future scan cache must be encrypted locally. The cache must be clearable from the Private/Security UI and must support explicit rescan. Raw decrypted scan material must not be written to UserDefaults or audit logs.

## Agent and Assistant Restrictions

Agent, Assistant, Context, and LLM layers must never receive wallet signing material or Cloak-specific secrets. They may receive only safe summaries such as public address, network, amount, fee quote, request id, status, and transaction signature.

Agent-controlled private wallet execution is not implemented. Future execution must require wallet unlock, LocalAuthentication, Shield review, explicit approval, local signing, send, confirmation, and audit.
