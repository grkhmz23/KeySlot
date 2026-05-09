# Cloak Private Payment Smoke

This is a manual mainnet-only smoke checklist for the Cloak private payment MVP. Do not run it from CI and do not automate it without an explicit human operator.

## Scope

Allowed:

- Shield SOL deposit with amount `>= 10_000_000` lamports
- Full withdraw / private pay from a locally stored Cloak record
- Bridge health and environment checks
- Local vault status checks

Not allowed:

- private swap
- batch payroll
- partial withdraw unless a later phase explicitly enables it
- scan/compliance export
- Agent-triggered execution

## Preconditions

- Use a mainnet wallet with only the tiny amount intended for smoke.
- Keep enough extra SOL for normal Solana transaction fees and for later withdraw/send fees.
- Confirm the Cloak program id is `zh1eLd6rSphLejbFfJEneUwzHRfMKxgzrgkfwA6qRkW`.
- Confirm the app is on `mainnet-beta`.
- Confirm Wallet -> Private shows the native signer bridge and local vault status.
- Confirm the wallet is unlocked immediately before execution.

## Deposit Smoke

1. Open Wallet -> Private.
2. Enter a tiny SOL amount that is at least `10_000_000` lamports.
3. Prepare the draft and review:
   - gross amount
   - fixed withdraw/send fee model `5_000_000` lamports
   - variable withdraw/send fee model `amount * 3 / 1000`
   - shielded amount
   - program id
   - mainnet warning
4. Run Bridge Health and Env Check.
5. Check all approval toggles.
6. Type the exact mainnet confirmation phrase:
   `I understand this is a real mainnet transaction.`
7. Approve, authenticate, sign, and shield SOL.
8. Confirm:
   - transaction signature appears
   - commitment prefix appears if SDK returned it
   - local private record appears in Private Activity
   - local vault status has a UTXO reference
   - audit log has safe before/after events

Do not paste or export private vault contents.

## Full Withdraw / Private Pay Smoke

1. Select the deposited local Cloak record.
2. Enter a recipient Solana public address.
3. Review amount, commitment prefix, leaf index, recipient, and mainnet warning.
4. Check all approval toggles.
5. Type the exact mainnet confirmation phrase.
6. Approve, authenticate, sign, and withdraw.
7. Confirm:
   - withdraw transaction signature appears
   - record state changes to spent
   - local spend state is removed from Keychain
   - audit log contains safe summary only

## Failure Checks

Expected blocking behavior:

- devnet network blocks execution
- missing wallet unlock blocks execution
- missing LocalAuthentication blocks signing
- wrong confirmation phrase blocks execution
- amount below `10_000_000` lamports blocks deposit
- wrong signer/public key mismatch blocks signing
- helper program id mismatch blocks execution
- expired or mismatched draft fingerprint blocks signing

## Environment Gate

No automatic mainnet smoke is enabled. A future scripted smoke must require:

```sh
GORKH_RUN_CLOAK_MAINNET_SMOKE=1
```

and must still require explicit human confirmation before sending a transaction.
