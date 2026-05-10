# Shield Review Approval Smoke

Use this checklist to validate that Shield Review improves approval context without adding execution paths.

## General

- Open Wallet.
- Confirm approval screens show a Shield Review card before final approval.
- Confirm the card shows status, risk, recognized action, programs, signer count, writable count, simulation status, and risk flags.
- Click "Open in Transaction Studio" and confirm only a safe summary appears.
- Confirm Transaction Studio still has no signing or broadcast controls.

## SOL Send

- Prepare a small SOL send draft.
- Simulate.
- Expected Shield Review:
  - System Program
  - System transfer
  - native SOL movement warning
  - simulation status
  - mainnet phrase requirement on mainnet

## SPL Token Send

- Prepare a token send draft.
- If recipient ATA is missing, confirm ATA creation appears.
- Expected Shield Review:
  - SPL Token or Token-2022
  - transferChecked action
  - token movement warning
  - Token-2022 hook/fee warnings when applicable

## Jupiter Swap

- Quote, build, review, and simulate a swap.
- Expected Shield Review:
  - Jupiter route
  - route labels where available
  - ALT warning when the built transaction uses lookup tables
  - simulation status
  - no direct execution from Shield Review

## Orca Harvest

- Build an Orca harvest plan for an owned LP position.
- Simulate before approval.
- Expected Shield Review:
  - Orca protocol interaction summary
  - writable/instruction counts
  - simulation status
  - unknown program warnings if present

## Cloak

- Prepare a Cloak deposit or full-withdraw approval.
- Expected Shield Review:
  - Cloak program interaction warning
  - local private-state warning
  - safe unavailable/raw-decode-limited wording when transaction bytes are not exposed
  - no private proof input, viewing key, nullifier, or local vault secret

## Zerion

- Open a Zerion tiny swap review.
- Expected Shield Review:
  - separate Zerion wallet notice
  - policy status
  - redacted command preview
  - raw transaction decode unavailable
  - no GORKH main-wallet signer access

## Failure Modes

- If simulation fails, existing approval policy must continue blocking where simulation is required.
- If Shield Review cannot decode a payload, it must show an honest unavailable reason.
- Shield Review must not persist raw transaction bytes by default.
