# Developer Workstation Localnet Smoke

This smoke validates the D2 localnet path without using mainnet.

## Check Mode

Run:

`scripts/workstation-localnet-smoke.sh --check`

Expected:

- sample Anchor project is present
- Solana CLI, solana-test-validator, and Anchor CLI availability is reported
- build/deploy is skipped
- no temporary keypair is created

## Live Mode

Run only when local toolchains are intentionally available:

`scripts/workstation-localnet-smoke.sh --live`

Expected:

- local validator is reused or started with fixed arguments
- temporary developer authority file is created under a temp directory
- file mode is `0600`
- sample Anchor project builds
- sample deploys to localnet
- temporary files are removed on exit

## Boundaries

- No mainnet program operations.
- No arbitrary flags.
- No unverified install step.
- No main GORKH wallet key material.
- No private key material in logs.
