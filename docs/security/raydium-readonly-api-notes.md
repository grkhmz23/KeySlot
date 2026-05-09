# Raydium Read-Only API Notes

Phase 3.5C integrates Raydium LP position display through public read-only HTTP APIs only.

## Reviewed Endpoints

Owner API:

- Mainnet: `https://owner-v1.raydium.io`
- Devnet: `https://owner-v1-devnet.raydium.io`
- `GET /position/stake/{owner}` for AMM/CPMM and farm/staked LP position data.
- `GET /position/clmm-lock/{owner}` for locked CLMM position data.

API v3 enrichment:

- Mainnet: `https://api-v3.raydium.io`
- Devnet: `https://api-v3-devnet.raydium.io`
- `GET /pools/info/ids?ids=...`
- `GET /mint/ids?mints=...`
- `GET /mint/price?mints=...`
- `GET /mint/list`
- `GET /farms/info/lp?lp=...&pageSize=10&page=1`

The Owner API is the source for wallet positions. API v3 is used only to enrich pool, mint, and price data.

## Safety Boundary

The Raydium adapter:

- does not request signing,
- does not build instructions,
- does not build transactions,
- does not call a Transaction API,
- does not import Raydium SDK transaction builders,
- does not add, remove, claim, harvest, close, create, stake, unstake, or swap.

Endpoint guard allowlist:

- `owner-v1.raydium.io`
- `owner-v1-devnet.raydium.io`
- `api-v3.raydium.io`
- `api-v3-devnet.raydium.io`

Blocked path or query terms include transaction, route, swap, build, execute, add/remove liquidity, claim, harvest, close, create pool, farm deposit, farm withdraw, auth, launch, and upload paths.

## Data Quality

Raydium Owner API and API v3 responses are cached and may lag recent wallet state. GORKH treats Raydium values as portfolio display data, not settlement truth.

`404` from Owner API wallet endpoints means the wallet has no returned positions for that endpoint and maps to an empty state.

If enrichment fails or response shape is incomplete, the adapter returns partial positions with safe identifiers and value unavailable. It does not fake token amounts, prices, fees, rewards, or lock data.

LP values remain separate from wallet token balances to avoid double-counting.

## Smoke

Run:

```bash
scripts/raydium-readonly-smoke.sh --mainnet --expected empty
```

Use a known public wallet:

```bash
GORKH_RAYDIUM_SMOKE_WALLET=<public-wallet> scripts/raydium-readonly-smoke.sh --mainnet
```

The smoke prints safe summaries only and never requires private keys, wallet files, or signing material.
