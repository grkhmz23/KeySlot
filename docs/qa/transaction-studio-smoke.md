# Transaction Studio Smoke

Transaction Studio v0.1 is decode/simulate/review only. It cannot sign, broadcast, call `requestAirdrop`, compose bundles, use Jito delivery, or run arbitrary RPC.

## Setup

1. Build the app.
2. Open `Transaction Studio` from the top-level sidebar.
3. Confirm the persistent safety banner says Studio cannot sign, broadcast, or move funds.
4. Use devnet unless explicitly reviewing a known mainnet signature.

## Smoke Cases

### Valid Signature

1. Paste a known Solana transaction signature.
2. Click `Decode`.
3. Expected:
   - RPC fetch attempts read-only `getTransaction`.
   - Decode timeline appears if RPC returns the transaction.
   - If unavailable, the UI shows an honest unavailable state.

### Invalid Signature

1. Paste a short or malformed string.
2. Click `Decode`.
3. Expected:
   - Decode fails locally.
   - No RPC send path appears.

### Address

1. Paste a public Solana address.
2. Click `Decode`.
3. Expected:
   - Public account owner, lamports, executable flag, and data length appear if RPC returns them.
   - Executable accounts show a program warning.

### Raw Transaction Decode

1. Paste a base64 or base58 encoded Solana transaction.
2. Click `Decode`.
3. Expected:
   - Transaction version, fee payer, static signers, writable accounts, program labels, and instruction timeline appear.
   - System transfer, SPL transfer, ATA create, Compute Budget, Memo, and Jupiter route instructions show parser badges when recognized.
   - Unknown instruction data remains explicitly unknown.

### Simulation Failure

1. Decode a stale or incomplete transaction.
2. Click `Simulate`.
3. Expected:
   - Simulation failure or unavailable state is shown.
   - Logs are displayed if RPC returns them.
   - Approval or signing controls do not appear.

### Unknown Program

1. Decode a transaction containing an unrecognized program ID.
2. Expected:
   - Program label is `Unknown Program`.
   - Risk review includes an unknown-program flag.

## Handoff Checks

- `Copy summary` copies explanation text only.
- `Send to Agent` routes to Agent without executing.
- Agent receives a safe parsed summary only, not raw transaction bytes.
- `Save history` stores a summary only.
- `Open Activity` is available only for signature-backed findings.

## Regression Checks

- No signing button.
- No broadcast button.
- No airdrop tool.
- No arbitrary RPC console.
- No bundle composer.
- No secret fields in history or audit.
