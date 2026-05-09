import Foundation

struct MarginFiReadOnlyAdapter: LendingPositionAdapter {
    let protocolKind: LendingProtocolKind = .marginFi

    private let programAccountExists: (WalletNetwork) async throws -> Bool
    private let accountFetcher: (WalletProfile, WalletNetwork) async throws -> [SolanaProgramAccountData]

    init(
        programAccountExists: @escaping (WalletNetwork) async throws -> Bool = { network in
            try await SolanaRPCClient().getAccountExists(address: MarginFiConstants.programID, network: network)
        },
        accountFetcher: @escaping (WalletProfile, WalletNetwork) async throws -> [SolanaProgramAccountData] = { profile, network in
            try await MarginFiAccountDiscovery().fetchAccounts(authority: profile, network: network)
        }
    ) {
        self.programAccountExists = programAccountExists
        self.accountFetcher = accountFetcher
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
                reason: MarginFiConstants.unsupportedNetworkReason,
                updatedAt: updatedAt
            )
        }

        do {
            try MarginFiEndpointGuard.validateProgramID(MarginFiConstants.programID)
            try MarginFiEndpointGuard.validateRPCMethod("getAccountInfo")
            try MarginFiEndpointGuard.validateRPCMethod("getProgramAccounts")
            let programReachable = try await programAccountExists(network)

            guard programReachable else {
                return LendingAdapterResult(
                    protocolKind: protocolKind,
                    status: .unavailable,
                    positions: [],
                    source: .solanaRPC,
                    updatedAt: updatedAt,
                    errorMessage: "MarginFi v2 program account was not found on mainnet-beta RPC.",
                    marketReserves: []
                )
            }

            var positions: [LendingPositionSummary] = []
            var errors: [String] = []
            for profile in profiles {
                do {
                    let accounts = try await accountFetcher(profile, network)
                    for account in accounts {
                        do {
                            let parsed = try MarginFiAccountParser.parse(
                                account: account,
                                expectedAuthority: profile.publicAddress
                            )
                            positions.append(position(
                                from: parsed,
                                profile: profile,
                                network: network,
                                updatedAt: updatedAt
                            ))
                        } catch {
                            errors.append("\(profile.label): \(error.localizedDescription)")
                        }
                    }
                } catch {
                    errors.append("\(profile.label): \(error.localizedDescription)")
                }
            }

            if !positions.isEmpty {
                let message = ([MarginFiConstants.partialParsingReason] + errors)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                return LendingAdapterResult(
                    protocolKind: protocolKind,
                    status: .partial,
                    positions: positions,
                    source: .solanaRPC,
                    updatedAt: updatedAt,
                    errorMessage: message,
                    marketReserves: []
                )
            }

            if !errors.isEmpty {
                return LendingAdapterResult(
                    protocolKind: protocolKind,
                    status: .error,
                    positions: [],
                    source: .solanaRPC,
                    updatedAt: updatedAt,
                    errorMessage: errors.joined(separator: " "),
                    marketReserves: []
                )
            }

            return LendingAdapterResult(
                protocolKind: protocolKind,
                status: .empty,
                positions: [],
                source: .solanaRPC,
                updatedAt: updatedAt,
                errorMessage: MarginFiConstants.positionParsingUnavailableReason,
                marketReserves: []
            )
        } catch {
            return LendingAdapterResult(
                protocolKind: protocolKind,
                status: .error,
                positions: [],
                source: .solanaRPC,
                updatedAt: updatedAt,
                errorMessage: error.localizedDescription,
                marketReserves: []
            )
        }
    }

    private func position(
        from parsed: MarginFiParsedAccount,
        profile: WalletProfile,
        network: WalletNetwork,
        updatedAt: Date
    ) -> LendingPositionSummary {
        let supplied = parsed.suppliedPositionCount
        let borrowed = parsed.borrowedPositionCount
        let unknown = parsed.unknownPositionCount
        let detail = [
            "\(supplied) supplied-share slot(s)",
            "\(borrowed) borrowed-share slot(s)",
            unknown > 0 ? "\(unknown) unknown side slot(s)" : nil
        ].compactMap { $0 }.joined(separator: ", ")

        return LendingPositionSummary(
            walletID: profile.id,
            walletLabel: profile.label,
            walletPublicAddress: profile.publicAddress,
            network: network,
            protocolKind: protocolKind,
            suppliedAssets: [],
            borrowedAssets: [],
            netValueUSD: nil,
            health: LendingHealthSummary(
                ltv: nil,
                liquidationThreshold: nil,
                healthFactor: nil,
                riskLevel: .unavailable,
                unavailableReason: "MarginFi health requires bank and oracle metadata parsing."
            ),
            source: .solanaRPC,
            updatedAt: updatedAt,
            status: .partial,
            errorMessage: "MarginFi account \(parsed.accountAddress) parsed read-only with \(detail).",
            unvaluedSuppliedPositionCount: supplied,
            unvaluedBorrowedPositionCount: borrowed,
            metadataStatus: "Asset metadata and values unavailable; bank parser not connected. Account \(parsed.accountAddress.shortAddress) / group \(parsed.groupAddress.shortAddress)."
        )
    }
}
