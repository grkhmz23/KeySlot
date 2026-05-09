import Foundation

enum PortfolioAggregator {
    static func aggregate(
        scope: PortfolioWalletScope,
        network: WalletNetwork,
        profiles: [WalletProfile],
        solBalances: [UUID: UInt64],
        tokenBalances: [UUID: [TokenBalance]],
        prices: [String: PortfolioPriceQuote],
        fetchedAt: Date = Date(),
        errors: [UUID: String] = [:]
    ) -> PortfolioAggregateSummary {
        let walletSummaries = profiles.map { profile in
            walletSummary(
                profile: profile,
                network: network,
                solLamports: solBalances[profile.id] ?? 0,
                tokenBalances: tokenBalances[profile.id] ?? [],
                prices: prices,
                fetchedAt: fetchedAt,
                errorMessage: errors[profile.id]
            )
        }

        let totalUSD = walletSummaries.reduce(Decimal(0)) { $0 + $1.totalUSD }
        let unavailablePriceCount = walletSummaries.reduce(0) { $0 + $1.unavailablePriceCount }
        let assetCount = walletSummaries.reduce(0) { $0 + $1.assets.count }
        let status: PortfolioDataStatus = errors.isEmpty ? .loaded : (walletSummaries.isEmpty ? .error : .stale)

        return PortfolioAggregateSummary(
            scope: scope,
            network: network,
            wallets: walletSummaries,
            totalUSD: totalUSD,
            unavailablePriceCount: unavailablePriceCount,
            assetCount: assetCount,
            priceSource: PortfolioConstants.priceSource,
            status: status,
            refreshedAt: fetchedAt,
            errorMessage: errors.values.sorted().joined(separator: " ")
        )
    }

    static func walletSummary(
        profile: WalletProfile,
        network: WalletNetwork,
        solLamports: UInt64,
        tokenBalances: [TokenBalance],
        prices: [String: PortfolioPriceQuote],
        fetchedAt: Date = Date(),
        errorMessage: String? = nil
    ) -> PortfolioWalletSummary {
        var values: [PortfolioTokenValue] = []
        let solAsset = PortfolioAssetBalance(
            walletID: profile.id,
            walletLabel: profile.label,
            walletPublicAddress: profile.publicAddress,
            network: network,
            mintAddress: PortfolioConstants.nativeSolMint,
            symbol: "SOL",
            name: "Solana",
            amountRaw: solLamports,
            decimals: 9,
            uiAmountString: TokenAmountFormatter.format(rawAmount: solLamports, decimals: 9),
            isNativeSOL: true,
            tokenAccountAddress: nil,
            tokenProgramKind: nil,
            accountState: nil,
            warnings: [],
            fetchedAt: fetchedAt
        )
        values.append(value(asset: solAsset, price: prices[PortfolioConstants.nativeSolMint]))

        for balance in tokenBalances {
            let metadata = TokenMetadataResolver.resolve(balance: balance, network: network)
            let warnings = TokenMetadataResolver.warnings(for: balance, metadata: metadata)
            let asset = PortfolioAssetBalance(
                walletID: profile.id,
                walletLabel: profile.label,
                walletPublicAddress: profile.publicAddress,
                network: network,
                mintAddress: balance.mintAddress,
                symbol: metadata.symbol,
                name: metadata.name,
                amountRaw: balance.amountRaw,
                decimals: metadata.decimals,
                uiAmountString: balance.uiAmountString,
                isNativeSOL: false,
                tokenAccountAddress: balance.tokenAccountAddress,
                tokenProgramKind: balance.programKind,
                accountState: balance.state,
                warnings: warnings,
                fetchedAt: balance.fetchedAt
            )
            values.append(value(asset: asset, price: prices[balance.mintAddress]))
        }

        let totalUSD = values.compactMap(\.usdValue).reduce(Decimal(0), +)
        return PortfolioWalletSummary(
            id: profile.id,
            label: profile.label,
            publicAddress: profile.publicAddress,
            network: network,
            assets: values,
            totalUSD: totalUSD,
            unavailablePriceCount: values.filter { $0.usdValue == nil }.count,
            fetchedAt: fetchedAt,
            errorMessage: errorMessage
        )
    }

    static func value(asset: PortfolioAssetBalance, price: PortfolioPriceQuote?) -> PortfolioTokenValue {
        guard let decimals = asset.decimals else {
            return PortfolioTokenValue(
                asset: asset,
                priceQuote: price,
                usdValue: nil,
                priceUnavailableReason: "Token decimals unavailable."
            )
        }
        guard let price, let usdPrice = price.usdPrice else {
            return PortfolioTokenValue(
                asset: asset,
                priceQuote: price,
                usdValue: nil,
                priceUnavailableReason: price?.errorMessage ?? "USD price unavailable."
            )
        }

        let amount = decimalAmount(rawAmount: asset.amountRaw, decimals: decimals)
        return PortfolioTokenValue(
            asset: asset,
            priceQuote: price,
            usdValue: amount * usdPrice,
            priceUnavailableReason: nil
        )
    }

    static func decimalAmount(rawAmount: UInt64, decimals: UInt8) -> Decimal {
        Decimal(rawAmount) / pow10(decimals)
    }

    private static func pow10(_ exponent: UInt8) -> Decimal {
        guard exponent > 0 else {
            return 1
        }
        return (0..<exponent).reduce(Decimal(1)) { value, _ in value * 10 }
    }
}
