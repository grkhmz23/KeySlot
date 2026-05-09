# Portfolio PnL / Cost Basis

Phase 3.7 adds a read-only Portfolio PnL / Performance panel inside Wallet -> Portfolio. The feature is a local analytics foundation, not tax advice and not tax-grade accounting.

## Scope

The PnL panel uses local portfolio snapshots, current portfolio balances, optional local cost-basis entries, and safe GORKH activity metadata. It does not request signing, build transactions, call execution SDKs, or send portfolio data to cloud AI.

Preferred user-facing language:

- Portfolio performance estimate
- Estimated PnL
- Cost basis incomplete
- Realized PnL unavailable
- Snapshot-based performance

Avoid product claims that imply official accounting, complete basis, or guaranteed profit/loss.

## Models

Core models live under `GORKH/Core/Portfolio/`:

- `PnLTimeframe`
- `PnLSource`
- `PnLAssetPerformance`
- `PnLWalletPerformance`
- `PnLPortfolioSummary`
- `PnLRealizedSummary`
- `PnLUnrealizedSummary`
- `CostBasisEntry`
- `CostBasisMethod`
- `PnLDataStatus`
- `PnLComparisonSnapshot`

The models contain public wallet addresses, token mints, token symbols, public amounts, USD estimates, source labels, timestamps, and status reasons. They do not contain private keys, seed phrases, mnemonics, wallet JSON, signing seed, transaction payloads, serialized transactions, or raw secret data.

## Snapshot Performance

`PnLCalculator` computes value deltas from existing `PortfolioSnapshot` history:

- current portfolio value from the current `PortfolioAggregateSummary`
- baseline snapshot for 24h, 7d, 30d, and all-time windows
- value delta and percentage delta where a baseline exists
- missing-price impact count
- per-asset and per-wallet estimates

If there is no usable previous snapshot, the timeframe is `unavailable` with an insufficient-history reason.

## Cost Basis

`CostBasisEntry` supports a safe local manual cost-basis foundation:

- wallet public address or all-wallet scope
- token mint and optional symbol
- quantity
- total cost USD
- acquisition date
- optional note
- created/updated timestamps

`CostBasisStore` writes only this public/accounting metadata to Application Support as `portfolio-cost-basis.json`. It does not use UserDefaults and does not store wallet secrets.

Manual entry editing is intentionally minimal in this phase. If no entries exist, unrealized PnL remains partial/unavailable.

## Swap Hints

`PnLActivityMapper` maps existing GORKH `swap_sent` audit events into cost-basis hints when safe fields are present:

- wallet public address
- signature
- input/output mints
- raw input/output amounts
- timestamp

Swap hints are not treated as complete cost basis because historical USD values, fees, and disposal context may be missing.

## Realized and Unrealized PnL

Realized PnL is computed only when disposal history and cost basis are sufficient. In this phase it generally reports:

`Realized PnL unavailable - insufficient cost basis or disposal history.`

Unrealized PnL is computed only for assets covered by local cost-basis entries and current USD value. Missing cost basis or missing prices produce partial/unavailable states.

## UI

`PortfolioPnLView` appears after Yield and before Snapshot History. It shows:

- current value
- 30d delta and percentage where available
- realized/unrealized status
- cost-basis coverage
- swap hint count
- timeframe rows
- asset and wallet performance estimates
- local cost-basis status

The panel labels execution as locked and uses explicit copy that this is an estimate, not tax-grade accounting.

## Audit

Safe audit events:

- `pnl_panel_viewed`
- `pnl_refreshed`
- `cost_basis_entry_added`
- `cost_basis_entry_updated`
- `cost_basis_entry_removed`
- `pnl_snapshot_generated`

Audit details include counts and status labels only. No secrets or raw transaction payloads are recorded.

## Limitations

The first PnL layer is intentionally conservative. It can be incomplete for:

- transfers between wallets
- airdrops
- staking rewards
- LP positions and changing pool inventory
- private Cloak flows
- missing price data
- external swaps not performed in GORKH
- old activity that lacks safe USD metadata

When data is incomplete, the panel reports partial or unavailable state instead of filling gaps with guesses.
