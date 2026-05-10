# Transaction Studio Architecture

Transaction Studio v0.1 is a Solana transaction workbench for decode, simulation, explanation, risk review, and safe handoff. It is intentionally read/review/simulation only.

## Scope

Transaction Studio supports:

- Solana transaction signature lookup through read-only RPC.
- Raw base64 or base58 transaction decoding.
- Public address account summary lookup.
- Read-only `simulateTransaction` for a decoded transaction when RPC allows it.
- Deterministic instruction parsing/labeling, risk flags, and plain-English explanation.
- Summary-only local history.
- Handoffs to Agent or Wallet Activity.

Transaction Studio does not support:

- signing,
- broadcasting,
- airdrops,
- arbitrary RPC consoles,
- bundle composition,
- Jito or priority bundle delivery systems,
- autonomous execution.

## Data Boundaries

Safe fields:

- public keys,
- program IDs,
- account metas,
- instruction indexes,
- signatures,
- blockhash,
- slot/time,
- program labels,
- logs and compute units from simulation.

Forbidden fields:

- seed phrases,
- private keys,
- wallet files,
- signing seed bytes,
- API keys,
- raw private payloads.

History stores only public references, summaries, risk level, simulation status, and timestamp. Raw transactions are not stored by default.

## Decode Pipeline

1. `TransactionStudioInputDetector` classifies input as signature, raw transaction, address, or unsupported.
2. `TransactionDecoder` parses legacy and v0 transaction structure locally.
3. `TransactionInstructionParser` delegates to small deterministic parsers for common program layouts.
4. `TransactionInstructionLabeler` still labels known programs and provides conservative fallback text.
5. Unknown data remains `Unknown instruction data`.
6. Address lookup uses public account info only.

Known labels include System Program, SPL Token, Token-2022, Associated Token Account, Compute Budget, Memo, Address Lookup Table, Jupiter, Orca Whirlpool, Raydium AMM/CPMM/CLMM, Meteora DLMM, Kamino, MarginFi, Cloak, and Unknown Program.

T2 parser coverage includes:

- System Program: transfer, create account, assign, allocate.
- SPL Token: transfer, transferChecked, approve, revoke, closeAccount, setAuthority partial decode, initializeAccount.
- Token-2022: same common token layouts with explicit extension-data-unavailable warnings.
- Associated Token Account: create/idempotent/recover-nested labels and account roles.
- Compute Budget: heap frame, compute unit limit, compute unit price.
- Memo: UTF-8 memo text with long memo truncation.
- Jupiter: route labeling only. Route internals remain opaque unless the layout is confidently known.

## Simulation

Simulation uses the existing Solana RPC client with `simulateTransaction`, `sigVerify: false`, and `replaceRecentBlockhash: false`.

Simulation never signs, never mutates signatures, and never submits the transaction. If RPC is unavailable or the transaction cannot be simulated, Studio shows an honest unavailable state.

## Risk Review

Risk flags are deterministic. Current flags cover:

- unknown programs,
- many writable accounts,
- unexpected signers,
- token transfers,
- native SOL transfers,
- authority changes,
- close-account instructions,
- delegate approvals,
- high compute unit limit/price,
- DeFi aggregator route,
- Token-2022 extension risk,
- upgradeable loader interaction,
- address lookup table use,
- high compute usage,
- failed or missing simulation,
- mainnet review,
- private protocol interaction,
- DeFi protocol interaction.

Risk labels are estimates for review, not guarantees.

## Handoffs

Allowed handoffs:

- copy summary,
- send finding to Agent for explanation,
- save summary to Studio history,
- open Wallet Activity for a signature.

Handoffs do not create an executable transaction path.

The Agent handoff sends a safe parsed summary, risk flags, simulation status, and public reference only. It does not include raw transaction bytes, serialized payloads, or secret fields.
