import Foundation

enum PortfolioAggregator {
    static func aggregate(
        scope: PortfolioWalletScope,
        network: WalletNetwork,
        profiles: [WalletProfile],
        solBalances: [UUID: UInt64],
        tokenBalances: [UUID: [TokenBalance]],
        prices: [String: PortfolioPriceQuote],
        stakeAccounts: [UUID: [StakeAccountSummary]] = [:],
        stakeErrors: [UUID: String] = [:],
        lendingAdapterResults: [LendingAdapterResult] = [],
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

        let liquidAssetsUSD = walletSummaries.reduce(Decimal(0)) { $0 + $1.totalUSD }
        let assetUnavailablePriceCount = walletSummaries.reduce(0) { $0 + $1.unavailablePriceCount }
        let assetCount = walletSummaries.reduce(0) { $0 + $1.assets.count }
        let combinedErrors = errors.merging(stakeErrors) { first, second in
            [first, second].filter { !$0.isEmpty }.joined(separator: " ")
        }
        let status: PortfolioDataStatus = combinedErrors.isEmpty ? .loaded : (walletSummaries.isEmpty ? .error : .stale)
        let consolidatedAssets = consolidateAssets(walletSummaries.flatMap(\.assets))
        let nativeStakeSummary = StakePortfolioAggregator.aggregate(
            profiles: profiles,
            accounts: stakeAccounts,
            errors: stakeErrors,
            solPrice: prices[PortfolioConstants.nativeSolMint],
            fetchedAt: fetchedAt
        )
        let lstSummary = LSTComparisonProvider.buildSummary(
            consolidatedAssets: consolidatedAssets,
            prices: prices,
            network: network,
            refreshedAt: fetchedAt
        )
        let lendingSummary = LendingPortfolioAggregator.aggregate(
            adapterResults: lendingAdapterResults,
            refreshedAt: fetchedAt
        )
        let totalUSD = liquidAssetsUSD + (nativeStakeSummary.estimatedUSD ?? 0)
        let unavailablePriceCount = assetUnavailablePriceCount + (nativeStakeSummary.priceUnavailable ? 1 : 0)
        let liquidSolLamports = solBalances.values.reduce(UInt64(0)) { partial, lamports in
            let result = partial.addingReportingOverflow(lamports)
            return result.overflow ? UInt64.max : result.partialValue
        }

        return PortfolioAggregateSummary(
            scope: scope,
            network: network,
            wallets: walletSummaries,
            consolidatedAssets: consolidatedAssets,
            liquidSolLamports: liquidSolLamports,
            liquidAssetsUSD: liquidAssetsUSD,
            nativeStakeSummary: nativeStakeSummary,
            lstSummary: lstSummary,
            lendingSummary: lendingSummary,
            totalUSD: totalUSD,
            unavailablePriceCount: unavailablePriceCount,
            assetCount: assetCount,
            priceSource: PortfolioConstants.priceSource,
            status: status,
            refreshedAt: fetchedAt,
            errorMessage: combinedErrors.values.sorted().joined(separator: " ")
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
            walletProfileKind: profile.profileKind,
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
                walletProfileKind: profile.profileKind,
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
            profileKind: profile.profileKind,
            colorTag: profile.colorTag,
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

    static func consolidateAssets(_ values: [PortfolioTokenValue]) -> [PortfolioConsolidatedAsset] {
        let grouped = Dictionary(grouping: values) { $0.asset.mintAddress }
        return grouped.map { mintAddress, mintValues in
            let sortedValues = mintValues.sorted {
                if $0.asset.walletLabel == $1.asset.walletLabel {
                    return $0.asset.walletPublicAddress < $1.asset.walletPublicAddress
                }
                return $0.asset.walletLabel < $1.asset.walletLabel
            }
            let first = sortedValues[0].asset
            let totalRaw = sortedValues.reduce(UInt64(0)) { partial, value in
                partial.addingReportingOverflow(value.asset.amountRaw).overflow ? UInt64.max : partial + value.asset.amountRaw
            }
            let decimals = first.decimals
            let totalUSDValues = sortedValues.compactMap(\.usdValue)
            let totalUSD = totalUSDValues.count == sortedValues.count
                ? totalUSDValues.reduce(Decimal(0), +)
                : nil
            let warnings = sortedValues
                .flatMap { $0.asset.warnings }
                .reduce(into: [TokenWarning]()) { partial, warning in
                    if !partial.contains(warning) {
                        partial.append(warning)
                    }
                }
                .sorted { $0.rawValue < $1.rawValue }
            return PortfolioConsolidatedAsset(
                mintAddress: mintAddress,
                symbol: first.symbol,
                name: first.name,
                decimals: decimals,
                totalAmountRaw: totalRaw,
                uiAmountString: decimals.map { TokenAmountFormatter.format(rawAmount: totalRaw, decimals: $0) } ?? "\(totalRaw)",
                totalUSD: totalUSD,
                priceQuote: sortedValues.first?.priceQuote,
                walletBreakdown: sortedValues,
                unavailablePriceCount: sortedValues.filter { $0.usdValue == nil }.count,
                warnings: warnings
            )
        }
        .sorted {
            if $0.isNativeSOL != $1.isNativeSOL {
                return $0.isNativeSOL
            }
            return $0.symbol < $1.symbol
        }
    }

    private static func pow10(_ exponent: UInt8) -> Decimal {
        guard exponent > 0 else {
            return 1
        }
        return (0..<exponent).reduce(Decimal(1)) { value, _ in value * 10 }
    }
}
