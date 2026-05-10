# Developer Workstation Program Ops Smoke

This smoke is for localnet/devnet program-operation readiness. Do not use mainnet program operations in D1.

## Preconditions

- Toolchain check completed.
- Project imported.
- Project explicitly trusted.
- Developer Workstation dev wallet generated.
- Cluster is localnet or devnet.
- No main GORKH Wallet key material is used.

## Localnet / Devnet Build

- Operation: Anchor build.
- Expected: requires Anchor CLI and trusted project.
- Expected command preview: fixed `anchor build`.
- Expected: blocked if project is untrusted or Anchor CLI missing.

## Localnet / Devnet Deploy

- Operation: Solana program deploy.
- Expected: requires Solana CLI, trusted project, developer wallet, and artifact path.
- Expected command preview uses fixed `solana program deploy` arguments.
- Expected: no arbitrary flags.

## Program Show

- Operation: Solana program show.
- Expected: read-only command allowed when Solana CLI is available and a program id is provided.
- Expected: mainnet show is read-only only.

## Close / Authority Operations

- Operation: program close or set upgrade authority.
- Expected: localnet/devnet only.
- Expected: destructive-operation phrase required.
- Expected phrase:

`I understand this local/devnet program operation can change or close a program.`

## Mainnet Lock

- Select mainnet-beta.
- Try deploy, close, or authority mutation.
- Expected: blocked with “Locked pending reviewed mainnet program-ops phase.”

## Temporary Keypair Handling

- If a command is actually run in a future manual smoke:
  - temp keypair file is created in a secure temp directory
  - file mode is `0600` where possible
  - command logs redact the path
  - temp directory is deleted immediately after command

## Evidence

- Record command preview only.
- Record success/failure status.
- Do not record private key material, wallet JSON, or local temp file contents.
