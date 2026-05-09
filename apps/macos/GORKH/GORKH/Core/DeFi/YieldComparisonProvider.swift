import Foundation

enum YieldComparisonProvider {
    static func buildSummary(
        scope: PortfolioWalletScope,
        network: WalletNetwork,
        lstSummary: LSTPortfolioSummary,
        lendingSummary: LendingPortfolioSummary,
        lpSummary: LPPortfolioSummary,
        pusdTreasurySummary: PUSDTreasurySummary,
        refreshedAt: Date
    ) -> YieldPortfolioSummary {
        var opportunities: [YieldOpportunity] = []
        var holdings: [YieldHolding] = []

        appendLST(
            scope: scope,
            summary: lstSummary,
            refreshedAt: refreshedAt,
            opportunities: &opportunities,
            holdings: &holdings
        )
        appendLending(
            scope: scope,
            summary: lendingSummary,
            refreshedAt: refreshedAt,
            opportunities: &opportunities,
            holdings: &holdings
        )
        appendLP(
            scope: scope,
            summary: lpSummary,
            refreshedAt: refreshedAt,
            opportunities: &opportunities,
            holdings: &holdings
        )
        appendPUSD(
            scope: scope,
            summary: pusdTreasurySummary,
            refreshedAt: refreshedAt,
            opportunities: &opportunities,
            holdings: &holdings
        )

        let heldOpportunityCount = opportunities.filter(\.isHeld).count
        let apyAvailableCount = opportunities.filter { $0.rate.value != nil }.count
        let unavailableCount = opportunities.filter {
            $0.status == .unavailable || $0.status == .error || $0.rate.value == nil
        }.count
        let holdingValues = holdings.compactMap(\.estimatedUSD)
        let totalYieldExposureUSD = holdings.isEmpty
            ? Decimal(0)
            : (holdingValues.count == holdings.count ? holdingValues.reduce(Decimal(0), +) : nil)
        let topYieldSourceLabel = opportunities
            .filter { $0.isHeld && $0.rate.value != nil }
            .max { lhs, rhs in
                (lhs.rate.value ?? 0) < (rhs.rate.value ?? 0)
            }?
            .label
        let status = summaryStatus(opportunities: opportunities, holdings: holdings)
        let errors = opportunities.compactMap(\.unavailableReason).filter { !$0.isEmpty }

        return YieldPortfolioSummary(
            status: status,
            opportunities: opportunities.sorted(by: opportunitySort),
            holdings: holdings.sorted { lhs, rhs in
                if lhs.sourceKind == rhs.sourceKind {
                    return lhs.label < rhs.label
                }
                return lhs.sourceKind.rawValue < rhs.sourceKind.rawValue
            },
            totalYieldExposureUSD: totalYieldExposureUSD,
            heldOpportunityCount: heldOpportunityCount,
            apyAvailableCount: apyAvailableCount,
            unavailableCount: unavailableCount,
            topYieldSourceLabel: topYieldSourceLabel,
            source: YieldConstants.source,
            noDoubleCountNotice: YieldConstants.noDoubleCountNotice,
            refreshedAt: refreshedAt,
            errorMessage: errors.isEmpty ? nil : errors.joined(separator: " ")
        )
    }

    private static func appendLST(
        scope: PortfolioWalletScope,
        summary: LSTPortfolioSummary,
        refreshedAt: Date,
        opportunities: inout [YieldOpportunity],
        holdings: inout [YieldHolding]
    ) {
        for holding in summary.holdings {
            holdings.append(YieldHolding(
                protocolKind: protocolKind(forLSTSymbol: holding.symbol),
                sourceKind: .lst,
                assetMint: holding.mintAddress,
                label: holding.symbol,
                walletScope: scope,
                heldAmountRaw: holding.amountRaw,
                heldAmount: holding.uiAmountString,
                estimatedUSD: holding.estimatedUSD,
                source: holding.dataSource,
                updatedAt: refreshedAt,
                status: holding.priceUnavailable ? .partial : .loaded,
                unavailableReason: holding.priceUnavailable ? "USD value unavailable for held LST." : nil
            ))
        }

        for entry in summary.comparison {
            let isHeld = entry.holdingAmountRaw > 0
            let status = status(for: entry.availability, rateAvailable: entry.apy != nil)
            let reason = entry.apy == nil
                ? (entry.unavailableReason ?? "LST APY, TVL, and exchange rate are unavailable from a connected safe source.")
                : nil
            opportunities.append(YieldOpportunity(
                protocolKind: protocolKind(forLSTSymbol: entry.symbol),
                sourceKind: .lst,
                assetMint: entry.mintAddress,
                label: entry.symbol,
                walletScope: scope,
                isHeld: isHeld,
                heldAmountRaw: entry.holdingAmountRaw,
                heldAmount: entry.uiAmountString,
                estimatedUSD: entry.estimatedUSD,
                rate: YieldRate(
                    kind: .apy,
                    value: entry.apy,
                    base: entry.apy,
                    reward: nil,
                    fee: nil,
                    source: entry.dataSource,
                    updatedAt: refreshedAt,
                    unavailableReason: reason
                ),
                tvlUSD: entry.tvlUSD,
                sourceEndpoint: entry.dataSource,
                updatedAt: refreshedAt,
                status: status,
                riskLevel: YieldRiskClassifier.classifyLST(status: status, isHeld: isHeld),
                unavailableReason: reason
            ))
        }
    }

    private static func appendLending(
        scope: PortfolioWalletScope,
        summary: LendingPortfolioSummary,
        refreshedAt: Date,
        opportunities: inout [YieldOpportunity],
        holdings: inout [YieldHolding]
    ) {
        for protocolSummary in summary.protocols {
            for position in protocolSummary.positions {
                let suppliedUSD = position.suppliedValueUSD
                holdings.append(YieldHolding(
                    protocolKind: protocolKind(for: protocolSummary.protocolKind),
                    sourceKind: .lending,
                    assetMint: nil,
                    label: "\(protocolSummary.protocolKind.displayName) position",
                    walletScope: scope,
                    heldAmountRaw: nil,
                    heldAmount: "\(position.suppliedAssets.count + position.unvaluedSuppliedPositionCount) supplied / \(position.borrowedAssets.count + position.unvaluedBorrowedPositionCount) borrowed",
                    estimatedUSD: suppliedUSD,
                    source: protocolSummary.source.rawValue,
                    updatedAt: protocolSummary.updatedAt,
                    status: status(for: position.status),
                    unavailableReason: position.errorMessage
                ))
            }

            if protocolSummary.marketReserves.isEmpty {
                opportunities.append(protocolLevelOpportunity(
                    protocolKind: protocolKind(for: protocolSummary.protocolKind),
                    sourceKind: .lending,
                    label: "\(protocolSummary.protocolKind.displayName) lending rates",
                    scope: scope,
                    source: protocolSummary.source.rawValue,
                    updatedAt: protocolSummary.updatedAt,
                    status: status(for: protocolSummary.status),
                    reason: protocolSummary.errorMessage ?? "Read-only lending market rates are unavailable.",
                    isHeld: !protocolSummary.positions.isEmpty
                ))
            } else {
                for reserve in protocolSummary.marketReserves {
                    let isHeld = protocolSummary.positions.contains { position in
                        position.suppliedAssets.contains { $0.mintAddress == reserve.mintAddress }
                            || position.borrowedAssets.contains { $0.mintAddress == reserve.mintAddress }
                    }
                    let rateReason = reserve.supplyAPY == nil ? "Supply APY unavailable for \(reserve.symbol)." : nil
                    let dataStatus: YieldDataStatus = reserve.supplyAPY == nil ? .partial : .loaded
                    opportunities.append(YieldOpportunity(
                        protocolKind: protocolKind(for: reserve.protocolKind),
                        sourceKind: .lending,
                        assetMint: reserve.mintAddress,
                        label: "\(reserve.protocolKind.displayName) \(reserve.symbol) supply",
                        walletScope: scope,
                        isHeld: isHeld,
                        heldAmountRaw: nil,
                        heldAmount: isHeld ? "held exposure" : nil,
                        estimatedUSD: reserve.totalSupplyUSD,
                        rate: YieldRate(
                            kind: .apy,
                            value: reserve.supplyAPY,
                            base: reserve.supplyAPY,
                            reward: nil,
                            fee: nil,
                            source: reserve.source.rawValue,
                            updatedAt: reserve.updatedAt,
                            unavailableReason: rateReason
                        ),
                        tvlUSD: reserve.totalSupplyUSD,
                        sourceEndpoint: reserve.source.rawValue,
                        updatedAt: reserve.updatedAt,
                        status: dataStatus,
                        riskLevel: YieldRiskClassifier.classifyLendingMarket(status: dataStatus),
                        unavailableReason: rateReason
                    ))
                }
            }
        }
    }

    private static func appendLP(
        scope: PortfolioWalletScope,
        summary: LPPortfolioSummary,
        refreshedAt: Date,
        opportunities: inout [YieldOpportunity],
        holdings: inout [YieldHolding]
    ) {
        for protocolSummary in summary.protocols {
            if protocolSummary.positions.isEmpty {
                opportunities.append(protocolLevelOpportunity(
                    protocolKind: protocolKind(for: protocolSummary.protocolKind),
                    sourceKind: .lp,
                    label: "\(protocolSummary.protocolKind.displayName) LP yield",
                    scope: scope,
                    source: protocolSummary.source.rawValue,
                    updatedAt: protocolSummary.updatedAt,
                    status: status(for: protocolSummary.status),
                    reason: protocolSummary.errorMessage ?? "LP APY/APR unavailable; no tracked position returned.",
                    isHeld: false
                ))
                continue
            }

            for position in protocolSummary.positions {
                holdings.append(YieldHolding(
                    protocolKind: protocolKind(for: protocolSummary.protocolKind),
                    sourceKind: .lp,
                    assetMint: position.positionMintAddress,
                    label: "\(protocolSummary.protocolKind.displayName) LP position",
                    walletScope: scope,
                    heldAmountRaw: nil,
                    heldAmount: position.positionAddress.shortAddress,
                    estimatedUSD: position.estimatedValueUSD,
                    source: position.source.rawValue,
                    updatedAt: position.updatedAt,
                    status: status(for: position.status),
                    unavailableReason: position.errorMessage
                ))
                let reason = lpRateReason(for: position)
                opportunities.append(YieldOpportunity(
                    protocolKind: protocolKind(for: protocolSummary.protocolKind),
                    sourceKind: .lp,
                    assetMint: position.positionMintAddress,
                    label: "\(protocolSummary.protocolKind.displayName) LP position",
                    walletScope: scope,
                    isHeld: true,
                    heldAmountRaw: nil,
                    heldAmount: position.positionAddress.shortAddress,
                    estimatedUSD: position.estimatedValueUSD,
                    rate: .unavailable(source: position.source.rawValue, updatedAt: position.updatedAt, reason: reason),
                    tvlUSD: nil,
                    sourceEndpoint: position.source.rawValue,
                    updatedAt: position.updatedAt,
                    status: position.status == .loaded ? .partial : status(for: position.status),
                    riskLevel: YieldRiskClassifier.classifyLP(position: position),
                    unavailableReason: reason
                ))
            }
        }
    }

    private static func appendPUSD(
        scope: PortfolioWalletScope,
        summary: PUSDTreasurySummary,
        refreshedAt: Date,
        opportunities: inout [YieldOpportunity],
        holdings: inout [YieldHolding]
    ) {
        if summary.hasBalance {
            holdings.append(YieldHolding(
                protocolKind: .palmUSD,
                sourceKind: .stablecoin,
                assetMint: summary.mintAddress,
                label: summary.symbol,
                walletScope: scope,
                heldAmountRaw: summary.totalAmountRaw,
                heldAmount: summary.uiAmountString,
                estimatedUSD: summary.estimatedUSD,
                source: summary.priceSource.rawValue,
                updatedAt: refreshedAt,
                status: summary.estimatedUSD == nil ? .partial : .loaded,
                unavailableReason: summary.estimatedUSD == nil ? "PUSD estimated USD value unavailable." : nil
            ))
        }

        opportunities.append(YieldOpportunity(
            protocolKind: .palmUSD,
            sourceKind: .stablecoin,
            assetMint: summary.mintAddress,
            label: "PUSD Treasury",
            walletScope: scope,
            isHeld: summary.hasBalance,
            heldAmountRaw: summary.totalAmountRaw,
            heldAmount: summary.uiAmountString,
            estimatedUSD: summary.estimatedUSD,
            rate: .unavailable(
                source: summary.priceSource.rawValue,
                updatedAt: refreshedAt,
                reason: YieldConstants.pusdYieldUnavailableReason
            ),
            tvlUSD: nil,
            sourceEndpoint: "wallet-pusd-treasury",
            updatedAt: refreshedAt,
            status: .unavailable,
            riskLevel: YieldRiskClassifier.classifyStablecoinYield(isActive: false),
            unavailableReason: YieldConstants.pusdYieldUnavailableReason
        ))
    }

    private static func protocolLevelOpportunity(
        protocolKind: YieldProtocol,
        sourceKind: YieldSourceKind,
        label: String,
        scope: PortfolioWalletScope,
        source: String,
        updatedAt: Date,
        status: YieldDataStatus,
        reason: String,
        isHeld: Bool
    ) -> YieldOpportunity {
        YieldOpportunity(
            protocolKind: protocolKind,
            sourceKind: sourceKind,
            assetMint: nil,
            label: label,
            walletScope: scope,
            isHeld: isHeld,
            heldAmountRaw: nil,
            heldAmount: nil,
            estimatedUSD: nil,
            rate: .unavailable(source: source, updatedAt: updatedAt, reason: reason),
            tvlUSD: nil,
            sourceEndpoint: source,
            updatedAt: updatedAt,
            status: status,
            riskLevel: .unavailable,
            unavailableReason: reason
        )
    }

    private static func protocolKind(forLSTSymbol symbol: String) -> YieldProtocol {
        switch symbol.lowercased() {
        case "jitosol":
            return .jito
        case "msol":
            return .marinade
        case "bsol":
            return .blazeStake
        case "bbsol":
            return .bybitStakedSol
        default:
            return .jito
        }
    }

    private static func protocolKind(for protocolKind: LendingProtocolKind) -> YieldProtocol {
        switch protocolKind {
        case .kamino:
            return .kamino
        case .marginFi:
            return .marginFi
        }
    }

    private static func protocolKind(for protocolKind: LPProtocolKind) -> YieldProtocol {
        switch protocolKind {
        case .meteora:
            return .meteora
        case .orca:
            return .orca
        case .raydium:
            return .raydium
        }
    }

    private static func status(for availability: LSTDataAvailability, rateAvailable: Bool) -> YieldDataStatus {
        if rateAvailable {
            return .loaded
        }
        switch availability {
        case .available, .priceOnly:
            return .partial
        case .unavailable:
            return .unavailable
        case .stale:
            return .stale
        }
    }

    private static func status(for status: LendingAdapterStatus) -> YieldDataStatus {
        switch status {
        case .idle:
            return .idle
        case .loaded:
            return .loaded
        case .empty:
            return .empty
        case .partial:
            return .partial
        case .unavailable:
            return .unavailable
        case .error:
            return .error
        case .stale:
            return .stale
        }
    }

    private static func status(for status: LPAdapterStatus) -> YieldDataStatus {
        switch status {
        case .idle:
            return .idle
        case .loaded:
            return .loaded
        case .empty:
            return .empty
        case .partial:
            return .partial
        case .unavailable:
            return .unavailable
        case .error:
            return .error
        case .stale:
            return .stale
        }
    }

    private static func summaryStatus(opportunities: [YieldOpportunity], holdings: [YieldHolding]) -> YieldDataStatus {
        guard !opportunities.isEmpty else {
            return .empty
        }
        if opportunities.contains(where: { $0.status == .error }) {
            return holdings.isEmpty ? .error : .partial
        }
        if opportunities.contains(where: { $0.status == .loaded }) {
            return opportunities.contains(where: { $0.status == .partial || $0.status == .stale || $0.status == .unavailable }) ? .partial : .loaded
        }
        if opportunities.contains(where: { $0.status == .partial }) {
            return .partial
        }
        if opportunities.allSatisfy({ $0.status == .unavailable || $0.status == .empty }) {
            return .unavailable
        }
        return .stale
    }

    nonisolated private static func opportunitySort(lhs: YieldOpportunity, rhs: YieldOpportunity) -> Bool {
        if lhs.isHeld != rhs.isHeld {
            return lhs.isHeld && !rhs.isHeld
        }
        if lhs.sourceKind != rhs.sourceKind {
            return lhs.sourceKind.rawValue < rhs.sourceKind.rawValue
        }
        return lhs.label < rhs.label
    }

    private static func lpRateReason(for position: LPPositionSummary) -> String {
        if position.protocolKind == .orca, position.feeSummary.totalUSD != nil {
            return "Harvestable fee value is available, but APY/APR is not derived from fee totals."
        }
        if position.protocolKind == .raydium {
            return "Raydium position data is read-only display data; APR is unavailable unless returned by a reviewed API field."
        }
        return "LP APY/APR is unavailable from the connected read-only adapter."
    }
}
