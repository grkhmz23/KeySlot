import Foundation

struct AgentRedactedContext: Codable, Equatable {
    struct WalletContext: Codable, Equatable {
        let selectedWallet: String?
        let walletKind: String?
        let canSign: Bool
        let network: String
        let rpcTokenStatus: String
    }

    struct PortfolioContext: Codable, Equatable {
        let totalValueUSD: Decimal
        let walletCount: Int
        let assetCount: Int
        let unavailablePriceCount: Int
        let status: String
    }

    struct PUSDContext: Codable, Equatable {
        let balance: String
        let estimatedUSD: Decimal?
        let walletCount: Int
        let priceSource: String
        let circulationStatus: String
    }

    struct YieldContext: Codable, Equatable {
        let status: String
        let heldOpportunityCount: Int
        let apyAvailableCount: Int
        let unavailableCount: Int
        let topSource: String?
    }

    struct LPContext: Codable, Equatable {
        let status: String
        let positionCount: Int
        let estimatedValueUSD: Decimal?
        let partialAdapterCount: Int
    }

    struct PnLContext: Codable, Equatable {
        let status: String
        let historyPointCount: Int
        let assetRows: Int
        let realizedStatus: String
        let copy: String
    }

    struct ActivityContext: Codable, Equatable {
        let recentEvents: [String]
    }

    struct SecurityContext: Codable, Equatable {
        let walletLockStatus: String
        let mainnetProtection: String
        let signingGuard: String
        let agentMainWalletAccess: String
        let rpcProviderStatus: String
    }

    struct ZerionContext: Codable, Equatable {
        let cliStatus: String
        let apiCredentialStatus: String
        let automationCredentialStatus: String
        let policyStatus: String
        let swapCommandShape: String
    }

    let wallet: WalletContext
    let portfolio: PortfolioContext
    let pusd: PUSDContext
    let yield: YieldContext
    let liquidity: LPContext
    let pnl: PnLContext
    let activity: ActivityContext
    let security: SecurityContext
    let zerion: ZerionContext
    let safetyMetadata: [String]
    let builtAt: Date
}

enum AgentRedactedContextError: Error, Equatable {
    case forbiddenFieldDetected(String)
    case encodingFailed
}

enum AgentRedactedContextBuilder {
    static func build(
        portfolioSummary: PortfolioAggregateSummary,
        pnlSummary: PnLPortfolioSummary,
        pusdCirculationSnapshot: PUSDCirculationSnapshot,
        auditEvents: [AuditEvent],
        selectedProfile: WalletProfile?,
        selectedNetwork: WalletNetwork,
        rpcSecurityStatus: RPCProviderSecurityStatus,
        zerionStatus: ZerionStatusSnapshot,
        builtAt: Date = Date()
    ) throws -> AgentRedactedContext {
        let context = AgentRedactedContext(
            wallet: .init(
                selectedWallet: selectedProfile?.publicAddress.shortAddress,
                walletKind: selectedProfile.map { safeWalletKind($0.profileKind) },
                canSign: selectedProfile?.canSign == true,
                network: selectedNetwork.displayName,
                rpcTokenStatus: rpcSecurityStatus.tokenStatus.displayName
            ),
            portfolio: .init(
                totalValueUSD: portfolioSummary.totalUSD,
                walletCount: portfolioSummary.wallets.count,
                assetCount: portfolioSummary.assetCount,
                unavailablePriceCount: portfolioSummary.unavailablePriceCount,
                status: portfolioSummary.status.title
            ),
            pusd: .init(
                balance: portfolioSummary.pusdTreasurySummary.uiAmountString,
                estimatedUSD: portfolioSummary.pusdTreasurySummary.estimatedUSD,
                walletCount: portfolioSummary.pusdTreasurySummary.holdingWalletCount,
                priceSource: portfolioSummary.pusdTreasurySummary.priceSource.title,
                circulationStatus: pusdCirculationSnapshot.status.title
            ),
            yield: .init(
                status: portfolioSummary.yieldSummary.status.title,
                heldOpportunityCount: portfolioSummary.yieldSummary.heldOpportunityCount,
                apyAvailableCount: portfolioSummary.yieldSummary.apyAvailableCount,
                unavailableCount: portfolioSummary.yieldSummary.unavailableCount,
                topSource: portfolioSummary.yieldSummary.topYieldSourceLabel
            ),
            liquidity: .init(
                status: portfolioSummary.lpSummary.status.title,
                positionCount: portfolioSummary.lpSummary.positionCount,
                estimatedValueUSD: portfolioSummary.lpSummary.estimatedValueUSD,
                partialAdapterCount: portfolioSummary.lpSummary.partialAdapterCount
            ),
            pnl: .init(
                status: pnlSummary.status.title,
                historyPointCount: pnlSummary.historyPointCount,
                assetRows: pnlSummary.assetPerformances.count,
                realizedStatus: pnlSummary.realized.status.title,
                copy: PnLConstants.notTaxGradeCopy
            ),
            activity: .init(
                recentEvents: auditEvents.prefix(5).map { event in
                    AgentSafetyRedactor.redact("\(event.kind.rawValue): \(event.message)")
                }
            ),
            security: .init(
                walletLockStatus: selectedProfile?.canSign == true ? "local signer selected" : "no local signer selected",
                mainnetProtection: "exact confirmation required for mainnet execution flows",
                signingGuard: "native approval guards remain active",
                agentMainWalletAccess: AgentMainWalletAccess.disabled.rawValue,
                rpcProviderStatus: "\(rpcSecurityStatus.provider.displayName):\(rpcSecurityStatus.tokenStatus.displayName)"
            ),
            zerion: .init(
                cliStatus: zerionStatus.cliStatus.label,
                apiCredentialStatus: zerionStatus.apiKeyStatus.label,
                automationCredentialStatus: zerionStatus.agentTokenStatus.label,
                policyStatus: zerionStatus.policyStatus.label,
                swapCommandShape: zerionStatus.swapCommandShape.label
            ),
            safetyMetadata: [
                "context_minimized",
                "wallet_addresses_redacted",
                "no_wallet_secrets",
                "no_raw_payloads",
                "proposals_require_policy"
            ],
            builtAt: builtAt
        )
        try validateContext(context)
        return context
    }

    static func redactedUserMessageForAI(_ message: String) throws -> (message: String, status: AgentRedactionStatus) {
        if let forbidden = firstForbiddenMatch(in: message) {
            throw AgentRedactedContextError.forbiddenFieldDetected(forbidden)
        }
        let redacted = AgentSafetyRedactor.redact(ZerionRedaction.redact(message))
        return (redacted, redacted == message ? .clean : .redacted)
    }

    static func validateContext(_ context: AgentRedactedContext) throws {
        guard let data = try? JSONEncoder().encode(context),
              let payload = String(data: data, encoding: .utf8) else {
            throw AgentRedactedContextError.encodingFailed
        }
        if let forbidden = firstForbiddenMatch(in: payload) {
            throw AgentRedactedContextError.forbiddenFieldDetected(forbidden)
        }
    }

    static func firstForbiddenMatch(in text: String) -> String? {
        let lowered = text.lowercased()
        let forbiddenTerms = [
            "private key",
            "privatekey",
            "seed phrase",
            "seedphrase",
            "mnemonic",
            "wallet json",
            "walletjson",
            "signing seed",
            "signingseed",
            "zerion_api_key",
            "api key",
            "agent token",
            "utxoprivatekey",
            "viewingkey",
            "nullifier",
            "proofinput",
            "transactionpayload",
            "serializedtransaction",
            "unsignedtransaction",
            "/bin/sh",
            "runshell",
            "arbitrarycommand"
        ]
        return forbiddenTerms.first { lowered.contains($0) }
    }

    private static func safeWalletKind(_ kind: WalletProfileKind) -> String {
        switch kind {
        case .watchOnly:
            return "Watch-only"
        case .hardwarePlaceholder:
            return "Hardware placeholder"
        case .multisigPlaceholder:
            return "Multisig placeholder"
        case .localSigner, .mnemonicDerived, .importedPrivateKey:
            return "Local signer"
        }
    }
}
