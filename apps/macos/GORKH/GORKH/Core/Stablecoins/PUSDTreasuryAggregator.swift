import Foundation

enum PUSDTreasuryAggregator {
    static func pegFallbackQuote(for asset: PortfolioAssetBalance, fetchedAt: Date = Date()) -> PortfolioPriceQuote? {
        guard isPUSD(mintAddress: asset.mintAddress), asset.network == .mainnetBeta else {
            return nil
        }
        return PortfolioPriceQuote(
            mintAddress: PUSDConstants.mintAddress,
            usdPrice: 1,
            source: PUSDConstants.stablecoinPegEstimateSource,
            blockID: nil,
            priceChange24h: nil,
            fetchedAt: fetchedAt,
            errorMessage: nil
        )
    }

    static func isPUSD(mintAddress: String) -> Bool {
        mintAddress == PUSDConstants.mintAddress
    }

    static func classifyPriceSource(from quote: PortfolioPriceQuote?) -> PUSDPriceSource {
        guard let quote, quote.usdPrice != nil else {
            return .unavailable
        }
        if quote.source == PUSDConstants.stablecoinPegEstimateSource {
            return .stablecoinPegEstimate
        }
        return .jupiterPrice
    }

    static func aggregate(summary: PortfolioAggregateSummary) -> PUSDTreasurySummary {
        aggregate(wallets: summary.wallets)
    }

    static func aggregate(wallets: [PortfolioWalletSummary]) -> PUSDTreasurySummary {
        let exposures: [PUSDWalletExposure] = wallets.compactMap { wallet -> PUSDWalletExposure? in
            let pusdValues = wallet.assets.filter { isPUSD(mintAddress: $0.asset.mintAddress) }
            guard !pusdValues.isEmpty else {
                return nil
            }
            let amountRaw = pusdValues.reduce(UInt64(0)) { partial, value in
                let result = partial.addingReportingOverflow(value.asset.amountRaw)
                return result.overflow ? UInt64.max : result.partialValue
            }
            guard amountRaw > 0 else {
                return nil
            }
            let usdValues = pusdValues.compactMap(\.usdValue)
            let estimatedUSD = usdValues.count == pusdValues.count ? usdValues.reduce(Decimal(0), +) : nil
            let quote = pusdValues.first?.priceQuote
            return PUSDWalletExposure(
                walletID: wallet.id,
                walletLabel: wallet.label,
                walletPublicAddress: wallet.publicAddress,
                walletProfileKind: wallet.profileKind,
                amountRaw: amountRaw,
                uiAmountString: TokenAmountFormatter.format(rawAmount: amountRaw, decimals: PUSDConstants.decimals),
                estimatedUSD: estimatedUSD,
                priceSource: classifyPriceSource(from: quote)
            )
        }
        .sorted {
            if $0.walletLabel == $1.walletLabel {
                return $0.walletPublicAddress < $1.walletPublicAddress
            }
            return $0.walletLabel < $1.walletLabel
        }

        guard !exposures.isEmpty else {
            return .empty
        }

        let totalRaw = exposures.reduce(UInt64(0)) { partial, exposure in
            let result = partial.addingReportingOverflow(exposure.amountRaw)
            return result.overflow ? UInt64.max : result.partialValue
        }
        let watchOnlyRaw = exposures
            .filter(\.isWatchOnly)
            .reduce(UInt64(0)) { partial, exposure in
                let result = partial.addingReportingOverflow(exposure.amountRaw)
                return result.overflow ? UInt64.max : result.partialValue
            }
        let totalUSDValues = exposures.compactMap(\.estimatedUSD)
        let estimatedUSD = totalUSDValues.count == exposures.count ? totalUSDValues.reduce(Decimal(0), +) : nil
        let priceSource = exposures.contains { $0.priceSource == .jupiterPrice }
            ? PUSDPriceSource.jupiterPrice
            : (exposures.contains { $0.priceSource == .stablecoinPegEstimate } ? .stablecoinPegEstimate : .unavailable)

        return PUSDTreasurySummary(
            mintAddress: PUSDConstants.mintAddress,
            symbol: PUSDConstants.symbol,
            decimals: PUSDConstants.decimals,
            totalAmountRaw: totalRaw,
            uiAmountString: TokenAmountFormatter.format(rawAmount: totalRaw, decimals: PUSDConstants.decimals),
            estimatedUSD: estimatedUSD,
            priceSource: priceSource,
            priceSourceDescription: priceSource.description,
            holdingWalletCount: exposures.count,
            watchOnlyAmountRaw: watchOnlyRaw,
            watchOnlyUIAmountString: TokenAmountFormatter.format(rawAmount: watchOnlyRaw, decimals: PUSDConstants.decimals),
            watchOnlyWalletCount: exposures.filter(\.isWatchOnly).count,
            walletBreakdown: exposures,
            sendFlow: PUSDActionPolicy.sendFlow,
            lockedFutureActions: PUSDActionPolicy.lockedFutureActions
        )
    }
}
