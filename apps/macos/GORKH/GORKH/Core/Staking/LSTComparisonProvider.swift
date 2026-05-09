import Foundation

enum LSTComparisonProvider {
    static let source = "local-lst-registry+jupiter-price"

    static let knownTokens: [LSTKnownToken] = [
        LSTKnownToken(
            mintAddress: "J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn",
            symbol: "JitoSOL",
            name: "Jito Staked SOL",
            network: .mainnetBeta,
            decimals: 9,
            riskNote: "Liquid staking token. Price and protocol risk remain separate from native stake."
        ),
        LSTKnownToken(
            mintAddress: "mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So",
            symbol: "mSOL",
            name: "Marinade Staked SOL",
            network: .mainnetBeta,
            decimals: 9,
            riskNote: "Liquid staking token. Review issuer and liquidity risk before acting."
        ),
        LSTKnownToken(
            mintAddress: "bSo13r4TkiE4KumL71LsHTPpL2euBYLFx6h9HP3piy1",
            symbol: "bSOL",
            name: "BlazeStake Staked SOL",
            network: .mainnetBeta,
            decimals: 9,
            riskNote: "Liquid staking token. Included as SPL holdings, not native stake."
        ),
        LSTKnownToken(
            mintAddress: "Bybit4u1pWg2s5YmtfsEfHZjUdsAaGYmHvcJVyzmFqLm",
            symbol: "bbSOL",
            name: "Bybit Staked SOL",
            network: .mainnetBeta,
            decimals: nil,
            riskNote: "Exchange-backed liquid staking token. Decimals come from on-chain token account data."
        )
    ]

    static func knownToken(mintAddress: String, network: WalletNetwork) -> LSTKnownToken? {
        knownTokens.first { $0.mintAddress == mintAddress && $0.network == network }
    }

    static func buildSummary(
        consolidatedAssets: [PortfolioConsolidatedAsset],
        prices: [String: PortfolioPriceQuote],
        network: WalletNetwork,
        refreshedAt: Date
    ) -> LSTPortfolioSummary {
        let holdings = consolidatedAssets.compactMap { asset -> LSTHoldingSummary? in
            guard let known = knownToken(mintAddress: asset.mintAddress, network: network) else {
                return nil
            }

            return LSTHoldingSummary(
                mintAddress: known.mintAddress,
                symbol: known.symbol,
                name: known.name,
                amountRaw: asset.totalAmountRaw,
                decimals: asset.decimals ?? known.decimals,
                uiAmountString: asset.uiAmountString,
                estimatedUSD: asset.totalUSD,
                priceQuote: asset.priceQuote ?? prices[known.mintAddress],
                walletBreakdown: asset.walletBreakdown,
                dataSource: source,
                priceUnavailable: asset.totalUSD == nil
            )
        }

        let comparison = knownTokens
            .filter { $0.network == network }
            .map { token in
                let holding = holdings.first { $0.mintAddress == token.mintAddress }
                let priceQuote = holding?.priceQuote ?? prices[token.mintAddress]
                let availability: LSTDataAvailability
                let unavailableReason: String?
                if holding != nil, priceQuote?.usdPrice != nil {
                    availability = .priceOnly
                    unavailableReason = "APY, TVL, and exchange rate are not connected to a safe public source yet."
                } else if holding != nil {
                    availability = .unavailable
                    unavailableReason = "Price is unavailable; APY, TVL, and exchange rate are not connected."
                } else {
                    availability = priceQuote?.usdPrice == nil ? .unavailable : .priceOnly
                    unavailableReason = "No holding detected. APY, TVL, and exchange rate are not connected."
                }

                return LSTComparisonEntry(
                    mintAddress: token.mintAddress,
                    symbol: token.symbol,
                    name: token.name,
                    holdingAmountRaw: holding?.amountRaw ?? 0,
                    uiAmountString: holding?.uiAmountString ?? "0",
                    estimatedUSD: holding?.estimatedUSD,
                    exchangeRate: nil,
                    apy: nil,
                    tvlUSD: nil,
                    priceQuote: priceQuote,
                    dataSource: source,
                    availability: availability,
                    unavailableReason: unavailableReason,
                    riskNote: token.riskNote
                )
            }

        let holdingUSDValues = holdings.compactMap(\.estimatedUSD)
        let totalUSD = holdingUSDValues.count == holdings.count ? holdingUSDValues.reduce(Decimal(0), +) : nil

        return LSTPortfolioSummary(
            holdings: holdings.sorted { $0.symbol < $1.symbol },
            comparison: comparison.sorted { $0.symbol < $1.symbol },
            totalUSD: totalUSD,
            holdingCount: holdings.count,
            priceUnavailableCount: holdings.filter(\.priceUnavailable).count,
            dataSource: source,
            refreshedAt: refreshedAt
        )
    }
}
