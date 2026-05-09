import Foundation

enum LPPortfolioAggregator {
    nonisolated static func aggregate(
        adapterResults: [LPAdapterResult],
        refreshedAt: Date = Date()
    ) -> LPPortfolioSummary {
        guard !adapterResults.isEmpty else {
            return .empty()
        }

        let protocols = adapterResults.map(protocolSummary)
        let positions = protocols.flatMap(\.positions)
        let valueParts = positions.compactMap(\.estimatedValueUSD)
        let estimatedValueUSD: Decimal? = valueParts.count == positions.count
            ? valueParts.reduce(Decimal(0), +)
            : nil
        let partialAdapterCount = adapterResults.filter { $0.status == .partial }.count
        let partialPositionCount = positions.filter { $0.status == .partial }.count
        let unavailableAdapterCount = adapterResults.filter { $0.status == .unavailable }.count
        let walletCount = Set(positions.map(\.walletPublicAddress)).count
        let status = portfolioStatus(for: adapterResults)
        let errorMessage = adapterResults
            .compactMap(\.errorMessage)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return LPPortfolioSummary(
            status: status,
            protocols: protocols,
            estimatedValueUSD: estimatedValueUSD,
            positionCount: positions.count,
            partialAdapterCount: partialAdapterCount,
            partialPositionCount: partialPositionCount,
            unavailableAdapterCount: unavailableAdapterCount,
            walletCount: walletCount,
            source: LPConstants.source,
            noDoubleCountNotice: LPConstants.noDoubleCountNotice,
            refreshedAt: refreshedAt,
            errorMessage: errorMessage.isEmpty ? nil : errorMessage
        )
    }

    nonisolated private static func protocolSummary(_ result: LPAdapterResult) -> LPProtocolSummary {
        let values = result.positions.compactMap(\.estimatedValueUSD)
        let value = values.count == result.positions.count
            ? values.reduce(Decimal(0), +)
            : nil
        let walletCount = Set(result.positions.map(\.walletPublicAddress)).count

        return LPProtocolSummary(
            protocolKind: result.protocolKind,
            status: result.status,
            positions: result.positions,
            estimatedValueUSD: value,
            positionCount: result.positions.count,
            partialPositionCount: result.positions.filter { $0.status == .partial }.count,
            walletCount: walletCount,
            source: result.source,
            updatedAt: result.updatedAt,
            errorMessage: result.errorMessage
        )
    }

    nonisolated private static func portfolioStatus(for results: [LPAdapterResult]) -> LPAdapterStatus {
        if results.contains(where: { $0.status == .loaded }) {
            return results.contains(where: { $0.status == .partial || $0.status == .stale || $0.status == .error }) ? .partial : .loaded
        }
        if results.contains(where: { $0.status == .partial }) {
            return .partial
        }
        if results.allSatisfy({ $0.status == .empty }) {
            return .empty
        }
        if results.contains(where: { $0.status == .error }) {
            return .error
        }
        if results.contains(where: { $0.status == .stale }) {
            return .stale
        }
        if results.contains(where: { $0.status == .unavailable }) {
            return .unavailable
        }
        return .idle
    }
}
