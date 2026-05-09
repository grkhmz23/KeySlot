# Cloak Private History Scan QA

Phase 2.6 adds read-only Cloak private history scan. This checklist does not send transactions and must not be used as a live payment smoke.

## Preconditions

- The wallet is on `mainnet-beta`.
- The selected wallet has local Cloak state from a prior approved Shield SOL smoke.
- The wallet is unlocked.
- LocalAuthentication is available or intentionally disabled in local wallet security settings.
- RPC Fast mainnet token is set locally when testing RPC Fast routing:
  - `GORKH_RPCFAST_MAINNET_TOKEN`
  - or `RPCFAST_MAINNET_TOKEN`

Do not paste private keys, seed phrases, wallet JSON, full UTXO objects, nullifiers, proof inputs, or scan credential material into the app, terminal, docs, or issue reports.

## Env Check

1. Open Wallet -> Private.
2. Run Bridge Env Check.
3. Confirm the response shows:
   - `rpcProvider` as `rpcfast` when a token is present, otherwise explicit fallback
   - `rpcHost` as host only
   - `rpcFastTokenStatus` as present/missing
   - no token value
   - no query-string API key

## Rescan

1. Click Rescan Private Activity.
2. Complete LocalAuthentication if prompted.
3. Confirm scan status becomes one of:
   - loaded
   - empty
   - partial
   - unavailable
   - error
4. Confirm failed/unavailable state explains the reason without exposing secrets.
5. Confirm the activity panel shows local, scanned, and matched counts.
6. Confirm activity rows use only:
   - transaction signature
   - amount
   - timestamp
   - status
   - commitment prefix
   - reconciliation state

## Compliance Summary

If scan succeeds, confirm the Compliance Summary panel shows only aggregate totals:

- transaction count
- total deposits
- total withdrawals
- total fees
- final balance
- generated timestamp

It must not show decrypted raw payloads, full notes, full UTXOs, nullifiers, proof inputs, or scan credential material.

## Cache Clear

1. Click Clear Scan Cache.
2. Confirm scan status changes to cache cleared.
3. Confirm local Cloak records remain visible.
4. Confirm spend state is not deleted.
5. Confirm audit contains a safe cache-cleared event.

## Expected Locked State

Partial withdraw remains locked with copy that it requires deposit/withdraw smoke and scan reconciliation validation.

No transaction should be sent by this QA flow.
