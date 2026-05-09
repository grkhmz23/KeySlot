# Yield / APY Comparison

Phase 3.6 adds a read-only Yield panel inside Wallet -> Portfolio.

## Scope

The panel compares yield exposure and available rates from existing Wallet data sources:

- LST holdings and comparison rows from the local LST registry plus portfolio prices.
- Kamino and MarginFi lending summaries from read-only lending adapters.
- Meteora, Orca, and Raydium LP summaries from the LP tracker.
- PUSD treasury balances and circulation context.

The feature does not create a new execution path. It does not request signing, build transactions, call action SDK methods, or change existing wallet approval gates. Existing Orca harvest remains a separate guarded user-approved flow.

## Models

Core models live in `GORKH/Core/DeFi/YieldModels.swift`:

- `YieldSourceKind`
- `YieldProtocol`
- `YieldOpportunity`
- `YieldHolding`
- `YieldRate`
- `YieldRiskLevel`
- `YieldDataStatus`
- `YieldPortfolioSummary`
- `YieldComparisonSnapshot`

All models store public portfolio display data only. They do not include private keys, seed phrases, wallet JSON, transaction payloads, instruction payloads, or signer data.

## Aggregation

`YieldPortfolioAggregator` and `YieldComparisonProvider` build the yield summary from `PortfolioAggregateSummary` inputs:

- `LSTPortfolioSummary`
- `LendingPortfolioSummary`
- `LPPortfolioSummary`
- `PUSDTreasurySummary`

No duplicate protocol clients are introduced. The yield panel reuses the existing read-only adapters and marks missing rate fields as unavailable instead of estimating them.

## APY/APR Rules

APY/APR is shown only when a connected read-only source provides it:

- Kamino supply APY is shown from lending reserve summaries when available.
- Lending markets without rates show partial or unavailable.
- LST rows currently show held/token value context, while APY/TVL/exchange rate remain unavailable unless a safe source is connected.
- LP rows show tracked positions and fee/value context where available; APY/APR remains unavailable unless the adapter provides a reviewed rate field.
- PUSD yield is unavailable. GORKH does not claim PUSD yield is active.

Cached protocol data can be stale. Missing values are not filled with fallback APY estimates.

## Risk Labels

`YieldRiskClassifier` applies deterministic labels:

- LST exposure is medium when held and data is otherwise usable.
- Lending exposure follows existing health/risk summaries where available.
- LP exposure is medium in range, high out of range, and unavailable when range/risk data is insufficient.
- Stablecoin yield risk is unavailable while PUSD yield is inactive.

These labels are informational and do not imply safety.

## Snapshots and Audit

Portfolio snapshots now include:

- total yield exposure USD when all held yield values are available,
- held opportunity count,
- APY available count,
- unavailable count,
- top held yield source label when a held source has a rate.

Audit events added:

- `yield_comparison_refreshed`
- `yield_source_unavailable`
- `yield_snapshot_stored`
- `yield_panel_viewed`

Audit payloads contain counts, status, source labels, and no secrets or raw protocol payloads.

## Non-Goals

This phase does not implement auto-yield execution, optimizer routing, new protocol execution, or new transaction builders.
