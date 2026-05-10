# Developer Workstation Smoke

Use this checklist for D3 local QA. Do not run untrusted project commands.

## App Navigation

- Open GORKH.
- Confirm top-level navigation shows Developer Workstation.
- Open Developer Workstation.
- Confirm sections are visible: Overview, Projects, Toolchain, IDL Browser, Program Manager, Logs, Account Decoder, RPC Playground, Compute Lab, Localnet, Offline Signing, Activity.

## Project Import

- Inspect an absolute local folder path.
- Expected: project imports as untrusted.
- Expected: detected framework and file counts appear if Anchor/Cargo/package files exist.
- Prepare an HTTPS Git URL.
- Expected: fixed git clone plan is prepared, but no command runs automatically.

## Trust Gate

- Try Program Manager with untrusted project.
- Expected: build/deploy operations are blocked.
- Enter the exact trust phrase.
- Expected: trust state changes to Trusted.

## Toolchain

- Click Check Toolchain.
- Expected: Solana CLI, AVM, Anchor, Rust, Cargo, Node, npm, and Git show available/missing states honestly.
- Expected: managed install plan appears for each tool.
- Expected: archive manifest entries are blocked until verified source and sha256 are filled.
- Expected: Anchor/AVM wizard shows detected Anchor, detected AVM, Cargo-backed AVM install plan, or Cargo missing blocker.
- Expected: bundled availability is not claimed unless app resources contain binaries.
- Missing tools should disable dependent program operations.

## IDL Browser

- Paste a small Anchor IDL fixture.
- Expected: instructions, accounts, types, errors, and events parse if present.
- Expected: instruction signer/writable counts and account discriminators are visible.
- Search for an instruction or account field.
- Expected: filtered rows update without running code.
- Invalid JSON should show a parse failure activity event.

## Account Decoder

- Enter a public account address and optional safe base64 fixture data.
- Expected: owner/data summary appears when available.
- If an Anchor discriminator and simple primitive fields match the loaded IDL, expected primitive values are shown.
- If complex fields are present, expected state is partial/unavailable rather than guessed.

## Logs

- Enter a valid program id.
- Start and stop log stream.
- Expected: bounded buffer and redacted lines.

## RPC Playground

- Select read-only methods such as `getHealth`, `getVersion`, `getBalance`, and `simulateTransaction`.
- Expected: required fields are validated.
- Select `sendTransaction`.
- Expected: blocked.
- Select broad `getProgramAccounts`.
- Expected: blocked.
- Select custom method.
- Expected: blocked.

## Faucet

- Select localnet or devnet.
- Enter a valid public key and a small amount.
- Expected: faucet request is allowed through faucet guard only.
- Select mainnet.
- Expected: blocked.

## Local Validator

- Check Localnet.
- Expected: local validator status and fixed start-command preview are visible when `solana-test-validator` is discoverable.
- Expected: reset ledger requires `Reset local validator ledger`.
- Expected: external validators are not stopped by GORKH.
- Expected: logs are bounded and redacted.
- Do not reset the ledger unless explicitly testing destructive localnet behavior.

## Sample Localnet Smoke

- Open Program Manager.
- Run Sample Localnet Smoke Preflight.
- Expected: preflight lists fixed steps and blockers.
- Expected: Anchor missing blocks live sample build/deploy.
- Expected: no live action runs automatically from preflight.

## Compute Lab

- Confirm compute lab states simulation-only and does not sign or broadcast.

## Offline Signing

- Confirm offline signing is foundation-only and cannot sign or broadcast.

## Activity

- Confirm Workstation activity records imports, trust, toolchain checks, log start/stop, and blocked commands without sensitive data.
