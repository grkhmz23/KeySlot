# PUSD Wallet Smoke

Phase PUSD-1 smoke is read/portfolio/send-flow verification only. Do not test mint/redeem or bridge flows because they are not implemented in GORKH.

## Metadata

1. Open Wallet on mainnet-beta.
2. Refresh Assets or Portfolio.
3. Confirm Palm USD resolves as:
   - symbol `PUSD`
   - mint `CZzgUBvxaMLwMhVSLgqJn3npmxoTo6nzMNQPAnwtHF3s`
   - decimals `6`
   - stablecoin category

## Portfolio / Treasury

1. Open Wallet -> Portfolio.
2. Confirm the PUSD Treasury panel is visible.
3. Confirm it shows:
   - total PUSD
   - wallets holding PUSD
   - watch-only exposure
   - price source
   - circulation status
   - locked future: mint/redeem, bridge, yield
4. If Jupiter has no PUSD price, confirm USD value is labeled as a stablecoin peg estimate, not a market quote.

## Receive / Payment Request

1. Click Receive PUSD.
2. Confirm the selected wallet public address and PUSD mint are shown.
3. Enter an optional amount.
4. Copy the address and payment note.
5. Confirm no personal data is requested and no backend invoice is created.

## Send PUSD

1. Use a signing wallet with an initialized PUSD token account and positive balance.
2. Unlock the wallet.
3. Click Send PUSD in the Treasury panel.
4. Confirm the existing SPL token send form opens for PUSD.
5. Prepare a token draft.
6. Simulate.
7. Approve only after the existing SPL approval guard passes.

Expected path:

draft -> simulation -> explicit approval -> wallet unlock -> LocalAuthentication -> native signing -> send -> confirmation -> audit

No shortcut signing path should appear.

## Circulation API Smoke

Optional no-auth check:

```bash
curl -fsSL https://www.palmusd.com/api/v1/circulation
```

Expected:

- JSON response if the public endpoint is available
- 429 handled as rate-limited if the endpoint soft limit is reached
- no API key required

The app should show unavailable/error honestly if the endpoint fails.

## Boundaries

GORKH must not:

- mint/redeem PUSD
- bridge PUSD
- add a new signing path
- store wallet secrets
- log wallet secrets
- execute automatically
