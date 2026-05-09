# Cloak Private Wallet

Phase 2.6 closes the non-live gaps around the Cloak Private MVP without adding new execution surfaces.

## Current Capabilities

- Mainnet-only SOL shield/deposit through `@cloak.dev/sdk` `transact`
- Mainnet-only full-withdraw/private pay through `fullWithdraw`
- Native Swift signer remains the only signing authority
- Keychain-backed local vault stores Cloak spend and scan state
- Read-only private history scan through `scanTransactions`
- Safe aggregate compliance summary from scan totals
- Local activity reconciliation between vault metadata and scan results
- Partial withdraw remains locked

No private swap, batch payment, Agent execution, or automated mainnet smoke is implemented.

## RPC Fast Routing

The Cloak helper now uses RPC Fast mainnet when a token exists in local environment:

- `GORKH_RPCFAST_MAINNET_TOKEN`
- `RPCFAST_MAINNET_TOKEN`

The helper passes the token only as an `X-Token` HTTP header to `https://solana-rpc.rpcfast.com/`. It does not use query string API keys and does not print, return, or persist the token.

If no token exists, the helper reports fallback status explicitly. Missing RPC Fast auth is visible in Wallet -> Private and env-check output.

## Scan Boundary

Read-only scan flow:

1. User clicks Rescan Private Activity.
2. Wallet must be unlocked.
3. LocalAuthentication is required when enabled.
4. Swift loads scan state from Keychain.
5. Swift sends the scan state transiently to the fixed helper command as `scanStateBase64`.
6. Helper calls `scanTransactions` only.
7. Helper returns safe summaries only.
8. Swift caches safe summaries and reconciles them with local activity metadata.

Forbidden scan response data:

- scan credential material
- full UTXO objects
- note contents
- nullifier secrets
- proof inputs
- raw decrypted payloads
- raw SDK response dumps

## Reconciliation

The reconciler classifies activity as:

- `matched`: local record signature was found in scan output
- `local_only`: local vault metadata exists but scan has not matched it yet
- `chain_only`: scan found activity not represented by local metadata
- `unknown`: reserved for future ambiguous states

Private balance is considered unavailable unless scan succeeds. The UI does not fake balance from local metadata alone.

## Cache Clear

Clear Private Scan Cache removes only safe scan summaries. It does not delete:

- wallet secrets
- Cloak spend state
- scan credential state
- local activity metadata

Full local private data deletion remains the existing separate vault-clear action.

## Locked Work

Partial withdraw remains locked until deposit/withdraw smoke and scan reconciliation are validated. Standalone compliance export remains locked; Phase 2.6 only exposes an aggregate summary after a safe scan.
