# Zerion Scoped Policy Templates

These templates describe safe policy shapes for the GORKH Agent + Zerion demo. They use placeholders only. Do not paste real API keys, agent tokens, recovery text, wallet files, or funded signing material into docs, screenshots, or commits.

Agent tokens have spending power. Treat them like API keys and rotate or revoke them immediately if exposed.

## Solana Tiny Swap Policy

Purpose: allow one tiny same-chain swap demo on Solana from a separate Zerion wallet.

Recommended shape:

- chain: `solana`
- expiry: 24 hours, or 7 days at most for rehearsal
- transfers: denied where supported
- approvals: denied where supported
- allowlist: restrict to the swap route/protocol accounts supported by Zerion policy if available
- wallet: separate tiny-funded Zerion wallet only
- notional: keep the GORKH local cap at the default tiny value

Manual command sketch:

```sh
zerion agent create-policy --chains solana --expires 24h --deny-transfers --deny-approvals --allowlist <reviewed-allowlist>
zerion agent create-token --policy <policy-id> --wallet <zerion-wallet-name>
```

## Base Tiny Swap Policy

Purpose: fallback demo if the installed CLI or policy setup is clearer for Base.

Recommended shape:

- chain: `base`
- expiry: 24 hours, or 7 days at most for rehearsal
- transfers: denied where supported
- approvals: denied where supported unless the selected route requires a reviewed allowance
- allowlist: restrict to the route/protocol targets supported by Zerion policy if available
- wallet: separate tiny-funded Zerion wallet only
- notional: keep the GORKH local cap at the default tiny value

Manual command sketch:

```sh
zerion agent create-policy --chains base --expires 24h --deny-transfers --deny-approvals --allowlist <reviewed-allowlist>
zerion agent create-token --policy <policy-id> --wallet <zerion-wallet-name>
```

## Short Expiry Rehearsal Policy

Use this when validating UI and policy detection without leaving a broad policy alive.

Recommended shape:

- selected chain only
- expiry: 1 hour to 24 hours
- transfers denied
- approvals denied where supported
- allowlist required when available
- revoke token immediately after the rehearsal

## Policy Review Checklist

- The wallet is not the GORKH main wallet.
- The wallet is tiny-funded only.
- The policy chain matches the proposal chain.
- The expiry is visible and short.
- Transfers are denied unless explicitly reviewed.
- Approvals are denied unless explicitly reviewed.
- The allowlist is narrow when available.
- The token status is present but the token value is never displayed.
- The GORKH review screen still requires the exact confirmation phrase.
