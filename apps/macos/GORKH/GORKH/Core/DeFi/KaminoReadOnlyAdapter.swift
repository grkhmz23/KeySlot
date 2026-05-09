import Foundation

struct KaminoReadOnlyAdapter: LendingPositionAdapter {
    let protocolKind: LendingProtocolKind = .kamino

    private let client: KaminoAPIClient
    private let marketScanLimit: Int
    private let marketContextLimit: Int

    init(
        client: KaminoAPIClient = KaminoAPIClient(),
        marketScanLimit: Int = 32,
        marketContextLimit: Int = 12
    ) {
        self.client = client
        self.marketScanLimit = marketScanLimit
        self.marketContextLimit = marketContextLimit
    }

    func fetchPositions(
        profiles: [WalletProfile],
        network: WalletNetwork,
        prices: [String: PortfolioPriceQuote]
    ) async -> LendingAdapterResult {
        let updatedAt = Date()
        guard network == .mainnetBeta else {
            return .unavailable(
                protocolKind: protocolKind,
                reason: "Kamino public lending API is mainnet-beta read-only only.",
                updatedAt: updatedAt
            )
        }

        do {
            let markets = try await client.fetchMarketConfigs(network: network)
            guard !markets.isEmpty else {
                return LendingAdapterResult(
                    protocolKind: protocolKind,
                    status: .unavailable,
                    positions: [],
                    source: .publicAPI,
                    updatedAt: updatedAt,
                    errorMessage: "Kamino public API returned no lending markets.",
                    marketReserves: []
                )
            }

            let contextMarket = markets.first(where: \.isPrimary) ?? markets[0]
            let reserveMetrics = try await client.fetchReserveMetrics(market: contextMarket, network: network)
            let marketReserves = reserveMetrics
                .prefix(marketContextLimit)
                .map { $0.marketSummary(market: contextMarket, updatedAt: updatedAt) }
            let reserveMap = Dictionary(uniqueKeysWithValues: reserveMetrics.map { ($0.reserve, $0) })

            var positions: [LendingPositionSummary] = []
            var obligationErrors: [String] = []
            let marketsToScan = Array(markets.prefix(marketScanLimit))
            for profile in profiles {
                for market in marketsToScan {
                    do {
                        let obligations = try await client.fetchUserObligations(
                            market: market,
                            walletAddress: profile.publicAddress,
                            network: network
                        )
                        positions.append(contentsOf: obligations.map {
                            Self.position(
                                obligation: $0,
                                market: market,
                                profile: profile,
                                network: network,
                                reserveMetrics: reserveMap,
                                prices: prices,
                                updatedAt: updatedAt
                            )
                        })
                    } catch {
                        obligationErrors.append("\(market.name): \(error.localizedDescription)")
                    }
                }
            }

            let status: LendingAdapterStatus
            let errorMessage: String?
            if !positions.isEmpty {
                status = obligationErrors.isEmpty ? .loaded : .stale
                errorMessage = obligationErrors.isEmpty ? nil : "Kamino positions loaded with partial market scan errors."
            } else if obligationErrors.isEmpty {
                status = .empty
                errorMessage = "No Kamino obligations were returned for the selected wallet scope across \(marketsToScan.count) reviewed read-only markets."
            } else {
                status = marketReserves.isEmpty ? .error : .stale
                errorMessage = "Kamino market data loaded, but wallet obligation lookup failed for all scanned markets."
            }

            return LendingAdapterResult(
                protocolKind: protocolKind,
                status: status,
                positions: positions,
                source: .publicAPI,
                updatedAt: updatedAt,
                errorMessage: errorMessage,
                marketReserves: marketReserves
            )
        } catch {
            return LendingAdapterResult(
                protocolKind: protocolKind,
                status: .error,
                positions: [],
                source: .publicAPI,
                updatedAt: updatedAt,
                errorMessage: error.localizedDescription,
                marketReserves: []
            )
        }
    }

    static func position(
        obligation: KaminoUserObligation,
        market: KaminoMarketConfig,
        profile: WalletProfile,
        network: WalletNetwork,
        reserveMetrics: [String: KaminoReserveMetric],
        prices: [String: PortfolioPriceQuote],
        updatedAt: Date
    ) -> LendingPositionSummary {
        let supplied = obligation.deposits.map {
            asset(asset: $0, reserveMetrics: reserveMetrics, prices: prices)
        }
        let borrowed = obligation.borrows.map {
            asset(asset: $0, reserveMetrics: reserveMetrics, prices: prices)
        }
        let healthFactor: Decimal?
        if let borrowUtilization = obligation.borrowUtilization, borrowUtilization > 0 {
            healthFactor = Decimal(1) / borrowUtilization
        } else {
            healthFactor = nil
        }

        let health = LendingHealthSummary(
            ltv: obligation.loanToValue,
            liquidationThreshold: nil,
            healthFactor: healthFactor,
            riskLevel: LendingHealthSummary.riskLevel(healthFactor: healthFactor, ltv: obligation.loanToValue),
            unavailableReason: nil
        )

        return LendingPositionSummary(
            walletID: profile.id,
            walletLabel: "\(profile.label) / \(market.name)",
            walletPublicAddress: profile.publicAddress,
            network: network,
            protocolKind: .kamino,
            suppliedAssets: supplied,
            borrowedAssets: borrowed,
            netValueUSD: obligation.netAccountValueUSD,
            health: health,
            source: .publicAPI,
            updatedAt: updatedAt,
            status: .loaded,
            errorMessage: nil,
            suppliedValueUSDOverride: obligation.userTotalDepositUSD,
            borrowedValueUSDOverride: obligation.userTotalBorrowUSD
        )
    }

    private static func asset(
        asset: KaminoObligationAsset,
        reserveMetrics: [String: KaminoReserveMetric],
        prices: [String: PortfolioPriceQuote]
    ) -> LendingAssetAmount {
        let metric = reserveMetrics[asset.reserveAddress]
        let symbol = metric?.liquidityToken ?? shortAddress(asset.reserveAddress)
        let mint = metric?.liquidityTokenMint ?? asset.reserveAddress
        let price = prices[mint]
        let usdValue = asset.usdValue
        return LendingAssetAmount(
            mintAddress: mint,
            symbol: symbol,
            name: metric.map { "\($0.liquidityToken) on Kamino" } ?? "Kamino reserve",
            amountRaw: asset.rawAmount ?? 0,
            decimals: nil,
            uiAmountString: asset.uiAmountString,
            usdValue: usdValue,
            priceQuote: price,
            source: .publicAPI
        )
    }

    private static func shortAddress(_ address: String) -> String {
        guard address.count > 10 else {
            return address
        }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}
