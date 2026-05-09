# RPC Fast Wallet Infrastructure

GORKH uses RPC Fast as the default Solana RPC provider for Wallet infrastructure.

## Default Endpoints

Devnet:
- HTTP: `https://sol-devnet-rpc.rpcfast.com`
- WebSocket: `wss://sol-devnet-rpc.rpcfast.com`

Mainnet beta:
- HTTP: `https://solana-rpc.rpcfast.com/`
- WebSocket: `wss://solana-rpc.rpcfast.com/`

The WebSocket endpoint is modeled for future subscription/status work. This phase does not add a general WebSocket subscription manager.

## Token Policy

RPC Fast tokens are local environment only:
- `GORKH_RPCFAST_DEVNET_TOKEN`
- `GORKH_RPCFAST_MAINNET_TOKEN`

Fallback names:
- `RPCFAST_DEVNET_TOKEN`
- `RPCFAST_MAINNET_TOKEN`

Tokens are sent only as an `X-Token` HTTP header. They must never appear in source code, UserDefaults, logs, audit events, snapshots, UI, or docs. Rotate any token that was pasted into chat or shared in plaintext.

If a token is missing, GORKH reports `token missing` and does not silently fall back to public Solana RPC.

## Method Safety

Wallet RPC calls use fixed Solana JSON-RPC methods only. There is no arbitrary RPC playground or user-provided RPC endpoint UI.

RPC Fast method notes:
- Most methods cost 1 CU.
- `getProgramAccounts` costs more and may be plan-limited.
- `getProgramAccounts`, `getTokenAccountsByOwner`, `getTokenAccountsByDelegate`, and `getTokenLargestAccounts` may have plan limitations.
- Token Program `getProgramAccounts` can be blocked on some plans, so GORKH token balances use `getTokenAccountsByOwner`.

Blocked, rate-limited, plan-upgrade, unauthorized, and timeout errors are normalized to clear non-crashing messages.

The native RPC client rejects unsupported method names before building a request. It also rejects Token Program `getProgramAccounts` usage so SPL balances stay on `getTokenAccountsByOwner`.

Read-heavy paths are intentionally bounded:
- SPL balances use `getTokenAccountsByOwner` per token program.
- Stake discovery uses filtered Stake Program queries and surfaces plan/provider errors as stale or unavailable state.
- Portfolio aggregation keeps wallet rows visible when a read path fails and marks the summary stale instead of fabricating balances.
- Lending and LP helper paths remain read-only and unavailable/partial when their fixed helper boundary cannot run safely.

## Health Checks

The health checker uses fixed read-only methods:
- `getHealth`
- `getVersion`
- `getSlot`
- `getBlockHeight`

It records latency, slot, block height, version, status, and updated time. It never sends transactions.

Local smoke:

```sh
scripts/rpcfast-wallet-smoke.sh --devnet --wallet <public-address>
scripts/rpcfast-wallet-smoke.sh --mainnet --wallet <public-address>
scripts/rpcfast-wallet-smoke.sh --all --wallet <public-address>
```

The smoke script reads local env tokens, sends them as `X-Token`, prints only redacted hosts/statuses, and never prints token values.

## Beam

RPC Fast Beam is recorded only as a locked future capability. This phase does not:
- append tip instructions
- call Beam `sendTransaction`
- call Beam `sendBundle`
- alter wallet or swap transaction delivery
- expose Beam provider controls

Future Beam work requires a separate design review covering tips, provider selection, simulation, approval, signing, delivery, confirmation, and audit.
