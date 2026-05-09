import Foundation

enum PnLCalculator {
    static func calculate(
        currentSummary: PortfolioAggregateSummary,
        snapshots: [PortfolioSnapshot],
        costBasisEntries: [CostBasisEntry] = [],
        swapActivityHints: [PnLSwapActivityHint] = [],
        generatedAt: Date = Date()
    ) -> PnLPortfolioSummary {
        guard currentSummary.status != .idle || !currentSummary.wallets.isEmpty else {
            return .empty(scope: currentSummary.scope, network: currentSummary.network, generatedAt: generatedAt)
        }

        let comparableSnapshots = comparableHistory(from: snapshots)
        let timeframePerformances = [PnLTimeframe.twentyFourHours, .sevenDays, .thirtyDays, .all].map { timeframe in
            performance(
                timeframe: timeframe,
                currentSummary: currentSummary,
                baseline: baselineSnapshot(for: timeframe, from: comparableSnapshots, generatedAt: generatedAt),
                generatedAt: generatedAt
            )
        }
        let primaryTimeframe: PnLTimeframe = .thirtyDays
        let primaryBaseline = baselineSnapshot(for: primaryTimeframe, from: comparableSnapshots, generatedAt: generatedAt)
            ?? baselineSnapshot(for: .all, from: comparableSnapshots, generatedAt: generatedAt)
        let assetPerformances = assetPerformance(
            currentSummary: currentSummary,
            baseline: primaryBaseline,
            generatedAt: generatedAt
        )
        let walletPerformances = walletPerformance(
            currentSummary: currentSummary,
            baseline: primaryBaseline,
            generatedAt: generatedAt
        )
        let costBasisCoverage = coverage(
            currentSummary: currentSummary,
            entries: costBasisEntries
        )
        let unrealized = unrealizedSummary(
            currentSummary: currentSummary,
            entries: costBasisEntries,
            coverage: costBasisCoverage
        )
        let realized = PnLRealizedSummary.unavailable(disposalEventCount: swapActivityHints.count)
        let status = summaryStatus(
            timeframePerformances: timeframePerformances,
            costBasisCoverage: costBasisCoverage,
            currentSummary: currentSummary
        )

        return PnLPortfolioSummary(
            generatedAt: generatedAt,
            scope: currentSummary.scope,
            network: currentSummary.network,
            currentValueUSD: currentSummary.totalUSD,
            currentWalletCount: currentSummary.wallets.count,
            currentAssetCount: currentSummary.assetCount,
            primaryTimeframe: primaryTimeframe,
            timeframePerformances: timeframePerformances,
            assetPerformances: assetPerformances,
            walletPerformances: walletPerformances,
            realized: realized,
            unrealized: unrealized,
            costBasisCoverage: costBasisCoverage,
            swapActivityHintCount: swapActivityHints.count,
            historyPointCount: snapshots.count,
            source: .portfolioSnapshot,
            status: status,
            reason: reason(for: status, timeframePerformances: timeframePerformances, costBasisCoverage: costBasisCoverage)
        )
    }

    static func snapshot(from summary: PnLPortfolioSummary) -> PnLComparisonSnapshot {
        let primary = summary.primaryPerformance
        return PnLComparisonSnapshot(
            generatedAt: summary.generatedAt,
            timeframe: summary.primaryTimeframe,
            currentValueUSD: summary.currentValueUSD,
            baselineValueUSD: primary?.baselineValueUSD,
            valueDeltaUSD: primary?.valueDeltaUSD,
            percentageDelta: primary?.percentageDelta,
            assetPerformanceCount: summary.assetPerformances.count,
            walletPerformanceCount: summary.walletPerformances.count,
            costBasisEntryCount: summary.costBasisCoverage.entryCount,
            status: summary.status,
            source: summary.source
        )
    }

    private static func comparableHistory(from snapshots: [PortfolioSnapshot]) -> [PortfolioSnapshot] {
        let sorted = snapshots.sorted { $0.createdAt < $1.createdAt }
        guard let latest = sorted.last?.createdAt else {
            return []
        }
        return sorted.filter { $0.createdAt < latest }
    }

    private static func baselineSnapshot(
        for timeframe: PnLTimeframe,
        from snapshots: [PortfolioSnapshot],
        generatedAt: Date
    ) -> PortfolioSnapshot? {
        guard !snapshots.isEmpty else {
            return nil
        }
        if let lookback = timeframe.lookbackSeconds {
            let cutoff = generatedAt.addingTimeInterval(-lookback)
            return snapshots.filter { $0.createdAt >= cutoff }.first
        }
        return snapshots.first
    }

    private static func performance(
        timeframe: PnLTimeframe,
        currentSummary: PortfolioAggregateSummary,
        baseline: PortfolioSnapshot?,
        generatedAt: Date
    ) -> PnLTimeframePerformance {
        guard let baseline else {
            return PnLTimeframePerformance(
                timeframe: timeframe,
                currentValueUSD: currentSummary.totalUSD,
                baselineValueUSD: nil,
                valueDeltaUSD: nil,
                percentageDelta: nil,
                baselineTimestamp: nil,
                currentTimestamp: generatedAt,
                missingPriceImpactCount: currentSummary.unavailablePriceCount,
                walletCount: currentSummary.wallets.count,
                assetCount: currentSummary.assetCount,
                source: .portfolioSnapshot,
                status: .unavailable,
                reason: "Insufficient snapshot history for \(timeframe.title) performance."
            )
        }

        let delta = currentSummary.totalUSD - baseline.totalUSD
        return PnLTimeframePerformance(
            timeframe: timeframe,
            currentValueUSD: currentSummary.totalUSD,
            baselineValueUSD: baseline.totalUSD,
            valueDeltaUSD: delta,
            percentageDelta: percentageDelta(delta: delta, baseline: baseline.totalUSD),
            baselineTimestamp: baseline.createdAt,
            currentTimestamp: generatedAt,
            missingPriceImpactCount: currentSummary.unavailablePriceCount + baseline.unavailablePriceCount,
            walletCount: currentSummary.wallets.count,
            assetCount: currentSummary.assetCount,
            source: .portfolioSnapshot,
            status: currentSummary.unavailablePriceCount + baseline.unavailablePriceCount == 0 ? .loaded : .partial,
            reason: currentSummary.unavailablePriceCount + baseline.unavailablePriceCount == 0
                ? nil
                : "One or more snapshot price points were unavailable."
        )
    }

    private static func assetPerformance(
        currentSummary: PortfolioAggregateSummary,
        baseline: PortfolioSnapshot?,
        generatedAt: Date
    ) -> [PnLAssetPerformance] {
        let previousByMint = baseline.map { previousAssetsByMint($0.assets) } ?? [:]
        return currentSummary.consolidatedAssets.map { asset in
            let previous = previousByMint[asset.mintAddress]
            let currentValue = asset.totalUSD
            let previousValue = previous?.usdValue
            let delta = valueDelta(current: currentValue, previous: previousValue)
            let status: PnLDataStatus
            let reason: String?
            if baseline == nil {
                status = .unavailable
                reason = "No previous snapshot is available for this asset."
            } else if currentValue == nil || previousValue == nil {
                status = .partial
                reason = "Current or previous USD value is unavailable."
            } else {
                status = .loaded
                reason = nil
            }

            return PnLAssetPerformance(
                walletScope: currentSummary.scope,
                tokenMint: asset.mintAddress,
                tokenSymbol: asset.symbol,
                currentAmountRaw: asset.totalAmountRaw,
                previousAmountRaw: previous?.amountRaw,
                amountDeltaRaw: previous.map { Decimal(asset.totalAmountRaw) - Decimal($0.amountRaw) },
                currentValueUSD: currentValue,
                previousValueUSD: previousValue,
                valueDeltaUSD: delta,
                percentageDelta: percentageDelta(delta: delta, baseline: previousValue),
                priceSource: asset.priceQuote?.source ?? currentSummary.priceSource,
                source: baseline == nil ? .unavailable : .portfolioSnapshot,
                timestamp: generatedAt,
                status: status,
                reason: reason
            )
        }
        .sorted {
            absolute($0.currentValueUSD ?? $0.valueDeltaUSD ?? 0) > absolute($1.currentValueUSD ?? $1.valueDeltaUSD ?? 0)
        }
    }

    private static func walletPerformance(
        currentSummary: PortfolioAggregateSummary,
        baseline: PortfolioSnapshot?,
        generatedAt: Date
    ) -> [PnLWalletPerformance] {
        let previousByWallet = baseline.map { previousWalletValues($0.assets) } ?? [:]
        return currentSummary.wallets.map { wallet in
            let previous = previousByWallet[wallet.publicAddress]
            let currentValue: Decimal? = wallet.unavailablePriceCount == 0 ? wallet.totalUSD : nil
            let previousValue = previous?.usdValue
            let delta = valueDelta(current: currentValue, previous: previousValue)
            let status: PnLDataStatus
            let reason: String?
            if baseline == nil {
                status = .unavailable
                reason = "No previous snapshot is available for this wallet."
            } else if currentValue == nil || previousValue == nil {
                status = .partial
                reason = "Current or previous wallet USD value is incomplete."
            } else {
                status = .loaded
                reason = nil
            }

            return PnLWalletPerformance(
                walletPublicAddress: wallet.publicAddress,
                walletLabel: wallet.label,
                walletKind: wallet.profileKind,
                currentValueUSD: currentValue,
                previousValueUSD: previousValue,
                valueDeltaUSD: delta,
                percentageDelta: percentageDelta(delta: delta, baseline: previousValue),
                assetCount: wallet.assets.count,
                missingPriceCount: wallet.unavailablePriceCount + (previous?.missingPriceCount ?? 0),
                source: baseline == nil ? .unavailable : .portfolioSnapshot,
                timestamp: generatedAt,
                status: status,
                reason: reason
            )
        }
    }

    private static func coverage(
        currentSummary: PortfolioAggregateSummary,
        entries: [CostBasisEntry]
    ) -> CostBasisCoverage {
        let currentAssets = currentSummary.consolidatedAssets.filter { $0.totalAmountRaw > 0 }
        guard !entries.isEmpty else {
            return CostBasisCoverage(
                method: .unavailable,
                entryCount: 0,
                coveredAssetCount: 0,
                missingAssetCount: currentAssets.count,
                totalCostUSD: nil,
                status: currentAssets.isEmpty ? .unavailable : .partial,
                reason: PnLConstants.costBasisMissingReason
            )
        }

        let coveredMints = Set(currentAssets.compactMap { asset in
            entries.contains { entry in
                entry.tokenMint == asset.mintAddress
                    && (entry.walletPublicAddress == nil || asset.walletBreakdown.contains { $0.asset.walletPublicAddress == entry.walletPublicAddress })
            } ? asset.mintAddress : nil
        })
        let totalCost = entries.reduce(Decimal(0)) { $0 + $1.totalCostUSD }
        let missing = max(0, currentAssets.count - coveredMints.count)
        return CostBasisCoverage(
            method: .manual,
            entryCount: entries.count,
            coveredAssetCount: coveredMints.count,
            missingAssetCount: missing,
            totalCostUSD: totalCost,
            status: missing == 0 ? .loaded : .partial,
            reason: missing == 0 ? nil : PnLConstants.costBasisMissingReason
        )
    }

    private static func unrealizedSummary(
        currentSummary: PortfolioAggregateSummary,
        entries: [CostBasisEntry],
        coverage: CostBasisCoverage
    ) -> PnLUnrealizedSummary {
        guard !entries.isEmpty else {
            return PnLUnrealizedSummary(
                estimatedUSD: nil,
                coveredAssetCount: 0,
                missingCostBasisAssetCount: coverage.missingAssetCount,
                source: .unavailable,
                status: coverage.missingAssetCount == 0 ? .unavailable : .partial,
                reason: PnLConstants.unrealizedPartialReason
            )
        }

        var coveredCurrentValue = Decimal(0)
        var hasMissingValue = false
        for asset in currentSummary.consolidatedAssets {
            guard entries.contains(where: { $0.tokenMint == asset.mintAddress }) else {
                continue
            }
            if let value = asset.totalUSD {
                coveredCurrentValue += value
            } else {
                hasMissingValue = true
            }
        }

        let totalCost = entries.reduce(Decimal(0)) { $0 + $1.totalCostUSD }
        let estimate = hasMissingValue ? nil : coveredCurrentValue - totalCost
        let status: PnLDataStatus = hasMissingValue || coverage.missingAssetCount > 0 ? .partial : .loaded
        return PnLUnrealizedSummary(
            estimatedUSD: estimate,
            coveredAssetCount: coverage.coveredAssetCount,
            missingCostBasisAssetCount: coverage.missingAssetCount,
            source: .manualCostBasis,
            status: status,
            reason: status == .loaded ? nil : PnLConstants.unrealizedPartialReason
        )
    }

    private static func summaryStatus(
        timeframePerformances: [PnLTimeframePerformance],
        costBasisCoverage: CostBasisCoverage,
        currentSummary: PortfolioAggregateSummary
    ) -> PnLDataStatus {
        guard !currentSummary.wallets.isEmpty else {
            return .unavailable
        }
        if timeframePerformances.allSatisfy({ $0.status == .unavailable }) {
            return .unavailable
        }
        if timeframePerformances.contains(where: { $0.status != .loaded }) || costBasisCoverage.status != .loaded {
            return .partial
        }
        return .loaded
    }

    private static func reason(
        for status: PnLDataStatus,
        timeframePerformances: [PnLTimeframePerformance],
        costBasisCoverage: CostBasisCoverage
    ) -> String? {
        switch status {
        case .loaded:
            return nil
        case .partial:
            if let unavailable = timeframePerformances.first(where: { $0.status == .unavailable }) {
                return unavailable.reason
            }
            return costBasisCoverage.reason
        case .unavailable:
            return "Portfolio PnL needs at least two local snapshots before performance can be estimated."
        case .stale:
            return "Portfolio PnL is based on stale local snapshots."
        case .error:
            return "Portfolio PnL could not be calculated."
        }
    }

    private struct PreviousAssetAggregate {
        let amountRaw: UInt64
        let usdValue: Decimal?
        let missingPriceCount: Int
    }

    private struct PreviousWalletAggregate {
        let usdValue: Decimal?
        let missingPriceCount: Int
    }

    private static func previousAssetsByMint(_ assets: [PortfolioSnapshotAsset]) -> [String: PreviousAssetAggregate] {
        Dictionary(grouping: assets, by: \.mintAddress).mapValues { values in
            let raw = values.reduce(UInt64(0)) { partial, value in
                let result = partial.addingReportingOverflow(value.amountRaw)
                return result.overflow ? UInt64.max : result.partialValue
            }
            return PreviousAssetAggregate(
                amountRaw: raw,
                usdValue: sumIfComplete(values.map(\.usdValue)),
                missingPriceCount: values.filter(\.priceUnavailable).count
            )
        }
    }

    private static func previousWalletValues(_ assets: [PortfolioSnapshotAsset]) -> [String: PreviousWalletAggregate] {
        Dictionary(grouping: assets, by: \.walletPublicAddress).mapValues { values in
            PreviousWalletAggregate(
                usdValue: sumIfComplete(values.map(\.usdValue)),
                missingPriceCount: values.filter(\.priceUnavailable).count
            )
        }
    }

    private static func sumIfComplete(_ values: [Decimal?]) -> Decimal? {
        let unwrapped = values.compactMap { $0 }
        guard unwrapped.count == values.count else {
            return nil
        }
        return unwrapped.reduce(Decimal(0), +)
    }

    private static func valueDelta(current: Decimal?, previous: Decimal?) -> Decimal? {
        guard let current, let previous else {
            return nil
        }
        return current - previous
    }

    private static func percentageDelta(delta: Decimal, baseline: Decimal) -> Decimal? {
        guard baseline != 0 else {
            return nil
        }
        return (delta / baseline) * 100
    }

    private static func percentageDelta(delta: Decimal?, baseline: Decimal?) -> Decimal? {
        guard let delta, let baseline else {
            return nil
        }
        return percentageDelta(delta: delta, baseline: baseline)
    }

    private static func absolute(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}
