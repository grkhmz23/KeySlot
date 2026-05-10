# Developer Workstation Localnet Smoke

This smoke validates the D3 localnet path without using mainnet.

## Check Mode

Run:

`scripts/workstation-localnet-smoke.sh --check`

Expected:

- sample Anchor project is present
- Solana CLI, solana-test-validator, and Anchor CLI availability is reported
- build/deploy is skipped
- no temporary keypair is created

## Staged Modes

- `scripts/workstation-localnet-smoke.sh --start-validator`
- `scripts/workstation-localnet-smoke.sh --build-sample`
- `scripts/workstation-localnet-smoke.sh --deploy-sample --skip-start-validator`
- `scripts/workstation-localnet-smoke.sh --full-localnet`

Run live modes only when local toolchains are intentionally available.

Expected:

- local validator is reused or started with fixed arguments unless `--skip-start-validator` is set
- temporary developer authority file is created under a temp directory
- file mode is `0600`
- sample Anchor project builds
- sample deploys to localnet with `solana program deploy`
- program id is verified with `solana program show`
- temporary files are removed on exit

If Anchor is missing, live build/deploy modes skip safely and report the blocker.

## Boundaries

- No mainnet program operations.
- No arbitrary flags.
- No unverified install step.
- No curl-pipe-sh bootstrap.
- No main GORKH wallet key material.
- No private key material in logs.
