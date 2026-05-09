import Foundation

struct PortfolioRefreshResult: Equatable {
    let summary: PortfolioAggregateSummary
    let priceErrorMessage: String?
}

struct PortfolioManager {
    let rpcClient: SolanaRPCClient
    let priceClient: any PortfolioPriceClient

    init(rpcClient: SolanaRPCClient, priceClient: any PortfolioPriceClient) {
        self.rpcClient = rpcClient
        self.priceClient = priceClient
    }

    func refresh(
        scope: PortfolioWalletScope,
        selectedWalletID: UUID?,
        profiles: [WalletProfile],
        network: WalletNetwork
    ) async -> PortfolioRefreshResult {
        let scopedProfiles = profilesForScope(scope, selectedWalletID: selectedWalletID, profiles: profiles)
        guard !scopedProfiles.isEmpty else {
            return PortfolioRefreshResult(
                summary: .empty(scope: scope, network: network),
                priceErrorMessage: nil
            )
        }

        var solBalances: [UUID: UInt64] = [:]
        var tokenBalances: [UUID: [TokenBalance]] = [:]
        var walletErrors: [UUID: String] = [:]
        var mintAddresses = Set<String>()
        mintAddresses.insert(PortfolioConstants.nativeSolMint)

        for profile in scopedProfiles {
            do {
                solBalances[profile.id] = try await rpcClient.getBalance(address: profile.publicAddress, network: network)
            } catch {
                walletErrors[profile.id] = error.localizedDescription
                solBalances[profile.id] = 0
            }

            do {
                let balances = try await rpcClient.getTokenBalances(ownerAddress: profile.publicAddress, network: network)
                tokenBalances[profile.id] = balances
                balances.forEach { mintAddresses.insert($0.mintAddress) }
            } catch {
                walletErrors[profile.id] = [walletErrors[profile.id], error.localizedDescription]
                    .compactMap { $0 }
                    .joined(separator: " ")
                tokenBalances[profile.id] = []
            }
        }

        let priceError: String?
        let prices: [String: PortfolioPriceQuote]
        do {
            prices = try await priceClient.fetchPrices(mintAddresses: Array(mintAddresses))
            priceError = nil
        } catch {
            prices = [:]
            priceError = error.localizedDescription
        }

        let summary = PortfolioAggregator.aggregate(
            scope: scope,
            network: network,
            profiles: scopedProfiles,
            solBalances: solBalances,
            tokenBalances: tokenBalances,
            prices: prices,
            fetchedAt: Date(),
            errors: walletErrors
        )

        if let priceError {
            return PortfolioRefreshResult(
                summary: PortfolioAggregateSummary(
                    scope: summary.scope,
                    network: summary.network,
                    wallets: summary.wallets,
                    consolidatedAssets: summary.consolidatedAssets,
                    totalUSD: summary.totalUSD,
                    unavailablePriceCount: summary.unavailablePriceCount,
                    assetCount: summary.assetCount,
                    priceSource: summary.priceSource,
                    status: .stale,
                    refreshedAt: summary.refreshedAt,
                    errorMessage: priceError
                ),
                priceErrorMessage: priceError
            )
        }

        return PortfolioRefreshResult(summary: summary, priceErrorMessage: nil)
    }

    private func profilesForScope(
        _ scope: PortfolioWalletScope,
        selectedWalletID: UUID?,
        profiles: [WalletProfile]
    ) -> [WalletProfile] {
        switch scope {
        case .activeWallet:
            guard let selectedWalletID,
                  let profile = profiles.first(where: { $0.id == selectedWalletID }) else {
                return []
            }
            return [profile]
        case .allWallets:
            return profiles
        case .localWallets:
            return profiles.filter(\.canSign)
        case .watchOnlyWallets:
            return profiles.filter(\.isWatchOnly)
        }
    }
}
