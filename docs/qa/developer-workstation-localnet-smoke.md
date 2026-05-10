# Developer Workstation Localnet Smoke

This smoke validates the D3 localnet path without using mainnet.

## Check Mode

Run:

`scripts/workstation-localnet-smoke.sh --check`

Expected:

- sample Anchor project is present
- Solana CLI, solana-test-validator, and usable Anchor CLI availability is reported
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

If Anchor is missing or the AVM shim is present but no Anchor version is active, live build/deploy modes skip safely and report the blocker before starting local validator.

## D4 Evidence

Recorded during Phase D4 on 2026-05-10:

- `cargo --version`: `cargo 1.94.0 (85eff7c80 2026-01-15)`
- `avm --version`: `avm 0.30.1`
- `anchor --version`: failed with `Anchor version not set`
- `solana --version`: `solana-cli 3.1.10`
- `solana-test-validator --version`: `solana-test-validator 3.1.10`

Anchor activation result:

- The approved fixed AVM bootstrap path installed AVM through Cargo.
- `avm install 0.30.1` was attempted through the approved fixed command path.
- Anchor CLI activation failed while compiling `anchor-cli 0.30.1`; dependency `time 0.3.29` failed to compile under the local Rust/Cargo 1.94 toolchain.
- No alternate unreviewed Anchor version, compiler flag, or install script was used.

Full localnet smoke result:

- `scripts/workstation-localnet-smoke.sh --check` passed and reported Anchor as found but unusable.
- `scripts/workstation-localnet-smoke.sh --full-localnet` skipped safely before starting local validator because Anchor CLI was not usable.
- No localnet program id was recorded.
- No temporary keypair was created by the final full-localnet smoke path after the Anchor blocker check.

Next action:

- Provide a verified compatible Anchor/AVM artifact or pin a compatible Rust toolchain, then rerun `scripts/workstation-localnet-smoke.sh --full-localnet`.

## Boundaries

- No mainnet program operations.
- No arbitrary flags.
- No unverified install step.
- No curl-pipe-sh bootstrap.
- No main GORKH wallet key material.
- No private key material in logs.
