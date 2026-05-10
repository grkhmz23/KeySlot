# Developer Workstation Smoke

Use this checklist for D1 local QA. Do not run untrusted project commands.

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
- Expected: Solana CLI, Anchor, Rust, Cargo, Node, npm, and Git show available/missing states honestly.
- Missing tools should disable dependent program operations.

## IDL Browser

- Paste a small Anchor IDL fixture.
- Expected: instructions, accounts, types, errors, and events parse if present.
- Invalid JSON should show a parse failure activity event.

## Account Decoder

- Enter a public account address and optional safe base64 fixture data.
- Expected: owner/data summary appears when available.
- If IDL decode is unavailable, UI says so honestly.

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

## Compute Lab

- Confirm compute lab states simulation-only and does not sign or broadcast.

## Offline Signing

- Confirm offline signing is foundation-only and cannot sign or broadcast.

## Activity

- Confirm Workstation activity records imports, trust, toolchain checks, log start/stop, and blocked commands without sensitive data.
