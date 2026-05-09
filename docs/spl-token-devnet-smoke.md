# GORKH SPL Token Devnet Smoke

This checklist validates Phase 1.3 SPL token behavior on Solana devnet only.

Do not use this flow on mainnet. Do not paste recovery phrases, private keys, or wallet JSON into logs, tickets, chats, or shell history.

## Prerequisites

- A GORKH devnet wallet with SOL for fees.
- A devnet SPL Token account owned by that wallet.

Phase 1.3 discovers Token-2022 balances, but Token-2022 sending is intentionally disabled until extension account handling is implemented. Phase 1.3B derives the recipient Associated Token Account for SPL Token sends and includes a create-ATA instruction before `transferChecked` when the recipient ATA is missing.

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
9. Enter a recipient owner address. If the owner does not have an ATA for this mint, GORKH must show that ATA creation is included before transfer.
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
  - draft must show the missing recipient ATA
  - approval must show `ATA creation included`
  - simulation must cover create ATA + transfer
  - audit must record `ata_creation_planned` and `ata_creation_included` after successful simulation
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

## Non-GUI Smoke Harness

The automated devnet SPL smoke uses the same gitignored throwaway wallet state as the SOL smoke:

```sh
scripts/live-devnet-wallet-smoke.sh --prepare-manual-funding
```

Fund the printed address with:

- devnet SOL for rent and fees
- a small devnet SPL Token balance

Then run:

```sh
scripts/live-devnet-spl-smoke.sh
```

To force a specific mint:

```sh
scripts/live-devnet-spl-smoke.sh --mint <SPL_TOKEN_MINT>
```

To validate the existing-recipient ATA path, rerun the smoke with a recipient owner that already received the same mint. This should produce a transfer transaction without ATA creation:

```sh
scripts/live-devnet-spl-smoke.sh --mint <SPL_TOKEN_MINT> --recipient-owner <OWNER_WITH_EXISTING_ATA>
```

If the smoke wallet has devnet SOL but no SPL balance, and local `solana` and `spl-token` CLIs are installed, create a temporary devnet-only SPL mint and mint test tokens to the smoke wallet:

```sh
scripts/live-devnet-spl-smoke.sh --prepare-token-balance
```

Then run the `nextCommand` printed by the setup step.

The default harness creates a fresh throwaway recipient owner, derives the missing recipient ATA, simulates create-ATA + `transferChecked`, signs locally, sends to devnet, waits for confirmation, and verifies the recipient token balance. When `--recipient-owner` is supplied, the harness uses that owner; if the ATA exists, it validates the transfer-only path. It prints only public addresses, token account addresses, the transaction signature, and the devnet explorer link.
