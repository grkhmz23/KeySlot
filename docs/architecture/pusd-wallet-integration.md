# PUSD Wallet Integration

Phase PUSD-1 adds Palm USD as a first-class stablecoin utility inside Wallet.

## Token Metadata

- Symbol: PUSD
- Name: Palm USD
- Network: Solana mainnet-beta
- Mint: `CZzgUBvxaMLwMhVSLgqJn3npmxoTo6nzMNQPAnwtHF3s`
- Decimals: 6
- Token type: standard SPL token
- Flags from the Palm USD reference:
  - non-freezable
  - no blacklist
  - no pause
  - standard SPL

GORKH does not add unsupported claims beyond the provided Palm USD reference.

## Portfolio And Treasury Mode

Portfolio aggregation detects PUSD by mint and groups it as a stablecoin. The PUSD Treasury panel shows:

- total PUSD across the selected portfolio scope
- wallet count holding PUSD
- watch-only exposure
- estimated USD value
- price source
- circulation API status
- send/receive shortcuts
- locked future capabilities

If Jupiter price data is unavailable for PUSD, GORKH uses a labeled `$1.00` stablecoin peg estimate. The UI labels this as:

`Stablecoin peg estimate, not market quote.`

PUSD values are still normal SPL token holdings and are included in wallet token balances. Lending and LP values remain separate to avoid double-counting.

## Send And Receive

The Send PUSD shortcut reuses the existing SPL token transfer flow:

draft -> simulation -> explicit approval -> wallet unlock -> LocalAuthentication -> native signing -> send -> confirmation -> audit

No PUSD-specific signing path exists. Watch-only wallets never show signing controls.

Receive/payment request is address-only:

- selected wallet public address
- PUSD mint
- optional amount in a copied payment note
- Solana mainnet warning

No invoicing backend or personal-data collection is added.

## Circulation API

GORKH reads the public no-auth Palm USD endpoint:

- `GET https://www.palmusd.com/api/v1/circulation`

The client handles:

- timeout
- HTTP error
- 429 rate limit
- flexible response normalization
- short in-memory cache

The history endpoint is documented for future use but is not required by this phase:

- `GET https://www.palmusd.com/api/v1/circulation/history`

Reserves and peg endpoints are not live according to the provided reference and are not called.

## Explicit Non-Goals

GORKH does not implement:

- mint/redeem
- bridge
- lending execution
- LP execution
- staking execution
- hidden signing
- automatic send
- Agent execution

Mint/redeem happens outside GORKH through Palm's permissioned perimeter. GORKH treats PUSD like a normal SPL token with dedicated treasury views and safe send/receive flows.
