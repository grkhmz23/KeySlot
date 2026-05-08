# GORKH SPL Token Devnet Smoke

This checklist validates Phase 1.3 SPL token behavior on Solana devnet only.

Do not use this flow on mainnet. Do not paste recovery phrases, private keys, or wallet JSON into logs, tickets, chats, or shell history.

## Prerequisites

- A GORKH devnet wallet with SOL for fees.
- A devnet SPL Token account owned by that wallet.
- A recipient owner address that already has an initialized token account for the same mint.

Phase 1.3 discovers Token-2022 balances, but Token-2022 sending is intentionally disabled until extension account handling is implemented. Phase 1.3 also detects when the recipient token account is missing and shows the ATA creation plan, but automatic ATA creation is deferred until PDA derivation is implemented without unsafe assumptions.

## Manual UI Smoke

1. Open GORKH.
2. Select the funded wallet.
3. Select `Devnet`.
4. Unlock the wallet.
5. Refresh SOL balance.
6. Refresh `SPL Tokens`.
7. Confirm the expected token row appears:
   - mint address
   - token account address
   - raw/UI amount
   - token program label
8. Click `Send` on an SPL Token row.
9. Enter a recipient owner address that already has a token account for the same mint.
10. Enter a small token amount.
11. Click `Prepare Token Draft`.
12. Confirm the draft shows:
    - network
    - mint
    - source token account
    - recipient owner
    - recipient token account
    - amount
    - ATA plan
13. Click `Simulate`.
14. Confirm simulation succeeds.
15. Click `Approve, Sign Locally, and Send Token`.
16. Confirm a transaction signature is shown.
17. Open the Solana Explorer link and verify the transaction on devnet.

## Expected Failure Checks

- Recipient owner has no token account for the mint:
  - draft must show the missing recipient token account
  - approval/send must stay blocked
  - audit must record `ata_creation_planned`
- Token-2022 token:
  - balance may be visible
  - send must be blocked with clear copy
- Mainnet:
  - no smoke send is run
  - exact mainnet confirmation phrase remains required

## Safety Checks

After a smoke run, verify:

```sh
git ls-files '*xcuserdata*' '*.xcuserstate' '.gorkh-devnet-smoke/*'
rg -n "privateKey|secretKey|seed phrase|wallet JSON|mnemonic" apps/macos/GORKH/GORKH docs scripts
```

The search may find source-level identifiers and safety copy, but it must not reveal actual secret material.
