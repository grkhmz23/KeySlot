import Foundation

enum StakePortfolioAggregator {
    static func aggregate(
        profiles: [WalletProfile],
        accounts: [UUID: [StakeAccountSummary]],
        errors: [UUID: String],
        solPrice: PortfolioPriceQuote?,
        fetchedAt: Date = Date()
    ) -> StakePortfolioSummary {
        let walletSummaries = profiles.map { profile in
            StakeWalletSummary(
                profile: profile,
                accounts: accounts[profile.id] ?? [],
                errorMessage: errors[profile.id]
            )
        }

        let totalDelegated = walletSummaries.reduce(UInt64(0)) { saturatingAdd($0, $1.totalDelegatedLamports) }
        let active = walletSummaries.reduce(UInt64(0)) { saturatingAdd($0, $1.activeLamports) }
        let activating = walletSummaries.reduce(UInt64(0)) { saturatingAdd($0, $1.activatingLamports) }
        let deactivating = walletSummaries.reduce(UInt64(0)) { saturatingAdd($0, $1.deactivatingLamports) }
        let inactive = walletSummaries.reduce(UInt64(0)) { saturatingAdd($0, $1.inactiveLamports) }
        let accountCount = walletSummaries.reduce(0) { $0 + $1.accounts.count }
        let validatorCount = Set(walletSummaries.flatMap { wallet in
            wallet.accounts.compactMap(\.validator?.voteAccount)
        }).count
        let estimatedUSD: Decimal?
        if let price = solPrice?.usdPrice {
            estimatedUSD = PortfolioAggregator.decimalAmount(rawAmount: totalDelegated, decimals: 9) * price
        } else {
            estimatedUSD = nil
        }
        let status: StakeDataStatus
        if !errors.isEmpty {
            status = accountCount == 0 ? .error : .stale
        } else {
            status = .loaded
        }

        let errorMessage = errors.isEmpty ? nil : errors.values.sorted().joined(separator: " ")
        return StakePortfolioSummary(
            status: status,
            wallets: walletSummaries,
            totalDelegatedLamports: totalDelegated,
            activeLamports: active,
            activatingLamports: activating,
            deactivatingLamports: deactivating,
            inactiveLamports: inactive,
            accountCount: accountCount,
            validatorCount: validatorCount,
            estimatedUSD: estimatedUSD,
            priceUnavailable: totalDelegated > 0 && estimatedUSD == nil,
            source: StakeConstants.source,
            refreshedAt: fetchedAt,
            errorMessage: errorMessage
        )
    }

    private static func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }
}
