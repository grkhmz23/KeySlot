import Foundation

enum LendingPortfolioAggregator {
    static func aggregate(
        adapterResults: [LendingAdapterResult],
        refreshedAt: Date = Date()
    ) -> LendingPortfolioSummary {
        guard !adapterResults.isEmpty else {
            return .empty(status: .idle)
        }

        let protocols = adapterResults.map { result in
            protocolSummary(result: result)
        }.sorted { $0.protocolKind.displayName < $1.protocolKind.displayName }

        let positionCount = protocols.reduce(0) { $0 + $1.positions.count }
        let riskyCount = protocols.reduce(0) { $0 + $1.riskyPositionCount }
        let partialCount = protocols.filter { $0.status == .partial }.count
        let suppliedPositionCount = protocols.reduce(0) { $0 + $1.suppliedPositionCount }
        let borrowedPositionCount = protocols.reduce(0) { $0 + $1.borrowedPositionCount }
        let unavailableCount = protocols.filter { $0.status == .unavailable }.count
        let marketReserveCount = protocols.reduce(0) { $0 + $1.marketReserveCount }
        let errors = protocols.compactMap(\.errorMessage).filter { !$0.isEmpty }
        let suppliedValues = protocols.compactMap(\.suppliedValueUSD)
        let borrowedValues = protocols.compactMap(\.borrowedValueUSD)
        let netValues = protocols.compactMap(\.netValueUSD)

        let supplied = suppliedValues.count == protocols.count ? suppliedValues.reduce(Decimal(0), +) : nil
        let borrowed = borrowedValues.count == protocols.count ? borrowedValues.reduce(Decimal(0), +) : nil
        let net = netValues.count == protocols.count ? netValues.reduce(Decimal(0), +) : nil

        let status: LendingAdapterStatus
        if protocols.contains(where: { $0.status == .error }) {
            status = positionCount > 0 ? .stale : .error
        } else if partialCount > 0 {
            status = .partial
        } else if unavailableCount == protocols.count {
            status = .unavailable
        } else if protocols.contains(where: { $0.status == .stale || $0.status == .unavailable }) {
            status = .stale
        } else if positionCount == 0 {
            status = .empty
        } else {
            status = .loaded
        }

        return LendingPortfolioSummary(
            status: status,
            protocols: protocols,
            suppliedValueUSD: supplied,
            borrowedValueUSD: borrowed,
            netValueUSD: net,
            positionCount: positionCount,
            riskyPositionCount: riskyCount,
            partialAdapterCount: partialCount,
            suppliedPositionCount: suppliedPositionCount,
            borrowedPositionCount: borrowedPositionCount,
            unavailableAdapterCount: unavailableCount,
            marketReserveCount: marketReserveCount,
            source: LendingConstants.source,
            noDoubleCountNotice: LendingConstants.noDoubleCountNotice,
            refreshedAt: refreshedAt,
            errorMessage: errors.isEmpty ? nil : errors.joined(separator: " ")
        )
    }

    static func protocolSummary(result: LendingAdapterResult) -> LendingProtocolSummary {
        let suppliedValues = result.positions.compactMap(\.suppliedValueUSD)
        let borrowedValues = result.positions.compactMap(\.borrowedValueUSD)
        let netValues = result.positions.compactMap(\.netValueUSD)
        let supplied = suppliedValues.count == result.positions.count ? suppliedValues.reduce(Decimal(0), +) : nil
        let borrowed = borrowedValues.count == result.positions.count ? borrowedValues.reduce(Decimal(0), +) : nil
        let net = netValues.count == result.positions.count ? netValues.reduce(Decimal(0), +) : nil
        let riskyCount = result.positions.filter {
            [.caution, .highRisk, .liquidationRisk].contains($0.health.riskLevel)
        }.count
        let walletCount = Set(result.positions.map(\.walletPublicAddress)).count
        let suppliedPositionCount = result.positions.reduce(0) {
            $0 + $1.suppliedAssets.count + $1.unvaluedSuppliedPositionCount
        }
        let borrowedPositionCount = result.positions.reduce(0) {
            $0 + $1.borrowedAssets.count + $1.unvaluedBorrowedPositionCount
        }

        return LendingProtocolSummary(
            protocolKind: result.protocolKind,
            status: result.status,
            positions: result.positions,
            suppliedValueUSD: supplied,
            borrowedValueUSD: borrowed,
            netValueUSD: net,
            riskyPositionCount: riskyCount,
            walletCount: walletCount,
            suppliedPositionCount: suppliedPositionCount,
            borrowedPositionCount: borrowedPositionCount,
            source: result.source,
            updatedAt: result.updatedAt,
            errorMessage: result.errorMessage,
            marketReserveCount: result.marketReserves.count,
            marketReserves: result.marketReserves
        )
    }
}
