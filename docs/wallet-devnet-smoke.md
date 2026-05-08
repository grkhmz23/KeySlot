# GORKH Wallet Devnet Smoke Checklist

Phase 1.1 must pass this checklist before any mainnet send is considered valid for real funds.

## Scope

This checklist validates:

- CryptoKit signing compatibility with Solana Ed25519 expectations
- BIP39-derived throwaway signer compatibility with the existing Solana transaction path
- Solana transfer message serialization
- devnet RPC balance, simulation, send, and confirmation
- audit events for wallet and transaction actions
- explorer link correctness

It does not validate SPL tokens, swaps, staking, lending, bridging, or agent execution.

## Preconditions

- Open `apps/macos/GORKH/GORKH.xcodeproj`.
- Build and run the `GORKH` macOS app.
- Confirm the wallet network selector is set to `Devnet`.
- Do not use mainnet for this checklist.
- Use a small devnet-only amount, recommended `0.001 SOL`.

Optional read-only RPC check:

```sh
scripts/devnet-smoke-checklist.sh
```

Automated live core smoke:

```sh
scripts/live-devnet-wallet-smoke.sh
```

The live script is devnet-only. It creates a throwaway BIP39-derived test signer without printing the phrase, requests a devnet airdrop, builds and simulates a 0.001 SOL transfer, signs locally, sends to devnet, waits for confirmation, and writes only public result metadata.

Manual-funding live core smoke, used when the public devnet faucet is rate-limited:

```sh
scripts/live-devnet-wallet-smoke.sh --prepare-manual-funding
```

Fund the printed devnet-only throwaway public address with at least `0.002` devnet SOL, then run:

```sh
scripts/live-devnet-wallet-smoke.sh --resume-manual-funding
```

Cleanup after the smoke test:

```sh
scripts/live-devnet-wallet-smoke.sh --cleanup
```

Manual-funding state is stored only under `.gorkh-devnet-smoke/`, which is gitignored. The script never prints private key material, seed phrases, wallet JSON, or raw signing material.

## Manual Smoke Steps

1. Create a local GORKH wallet in the app.
2. Copy the displayed public address.
3. Fund the address with devnet SOL using a trusted faucet or Solana CLI.
4. Click `Refresh` and verify the balance increases.
5. Prepare a recipient devnet address. This can be a second local test wallet.
6. In `Send SOL`, enter the recipient and `0.001`.
7. Click `Prepare Draft`.
8. Verify the draft shows:
   - network: Devnet
   - from: GORKH wallet public address
   - to: recipient address
   - amount: 0.001 SOL
9. Click `Simulate`.
10. Verify simulation succeeds and logs are shown if RPC returns logs.
11. Click `Approve, Sign Locally, and Send`.
12. Verify a transaction signature appears.
13. Open the explorer link and verify the devnet transaction.
14. Refresh balance and verify lamports changed by amount plus fee.
15. Confirm the audit log includes safe events only:
   - wallet created or imported
   - balance refreshed
   - transaction drafted
   - transaction simulated
   - transaction approved
   - transaction sent

## Pass Criteria

- The signed transaction is accepted by devnet RPC.
- The signature reaches at least `confirmed` confirmation.
- Sender balance decreases by transfer amount plus fee.
- Recipient balance increases by transfer amount.
- Audit log contains no private key, seed, mnemonic, or raw wallet JSON.
- No mainnet transaction was attempted.

## Mainnet Gate

Mainnet send UI must remain gated until this checklist has passed for the exact build being tested.
The UI requires explicit mainnet confirmation and acknowledgment that the devnet smoke send has completed.
