# RPC Fast Wallet Smoke

This smoke verifies GORKH Wallet is using RPC Fast as the default Solana RPC provider.

## Setup

Create a local `.env` outside source control or launch Xcode with these environment variables:

```sh
export GORKH_RPCFAST_DEVNET_TOKEN
export GORKH_RPCFAST_MAINNET_TOKEN
```

Fallback names are supported:

```sh
export RPCFAST_DEVNET_TOKEN
export RPCFAST_MAINNET_TOKEN
```

Do not commit `.env`. Rotate any token that was pasted into chat or shared in plaintext.

## Manual QA

1. Launch GORKH with a devnet RPC Fast token.
2. Open Wallet.
3. Confirm the header shows `RPC Fast`.
4. Open Settings -> Security -> RPC Infrastructure.
5. Confirm:
   - provider is RPC Fast
   - HTTP host is `sol-devnet-rpc.rpcfast.com` on devnet
   - WebSocket host is `sol-devnet-rpc.rpcfast.com` on devnet
   - token status is present
   - Beam is locked for future review
6. Click `Check RPC Health`.
7. Confirm health reports latency plus slot or block height.
8. Switch to Mainnet Beta.
9. Confirm the mainnet host is `solana-rpc.rpcfast.com` and token status reflects only local env state.

## Missing Token QA

Launch without a token for a network. The app should show `Token missing` and should not fall back to public Solana RPC silently.

## Error QA

If the provider returns a plan or method error, GORKH should show a clear non-crashing message such as:
- RPC Fast token missing
- RPC method requires plan upgrade
- RPC method is blocked for this program
- Endpoint timed out

## Exclusions

This phase does not add Beam transaction delivery, Jito bundles, arbitrary RPC tools, user custom RPC UI, or any new execution feature.
