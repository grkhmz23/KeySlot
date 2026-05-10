import Foundation

enum TransactionRiskAnalyzer {
    private static let writableAccountWarningThreshold = 24
    private static let highComputeUnitThreshold: UInt64 = 1_200_000

    static func review(decoded: DecodedTransaction?, simulation: TransactionStudioSimulationSummary) -> TransactionRiskReview {
        guard let decoded else {
            return TransactionRiskReview(
                level: .unknown,
                flags: [
                    TransactionRiskFlag(
                        kind: .missingSimulation,
                        level: .unknown,
                        message: "No decoded transaction is available for risk review."
                    )
                ],
                generatedAt: Date()
            )
        }

        var flags: [TransactionRiskFlag] = []
        let programLabels = Set(decoded.programSummaries.map(\.label))
        let actions = decoded.instructions.map(\.decodedAction)

        if decoded.programSummaries.contains(where: { $0.label == "Unknown Program" }) {
            flags.append(.init(kind: .unknownProgram, level: .high, message: "One or more instructions use an unknown program. Review program IDs before approval."))
        }
        if decoded.writableAccounts.count >= writableAccountWarningThreshold {
            flags.append(.init(kind: .manyWritableAccounts, level: .medium, message: "Transaction has \(decoded.writableAccounts.count) writable static accounts. Larger writable sets increase review complexity."))
        }
        let extraSigners = decoded.signerSummaries.filter { !$0.isFeePayer }
        if extraSigners.isEmpty == false {
            flags.append(.init(kind: .unexpectedSigner, level: .high, message: "Transaction requires signer(s) beyond the fee payer. Confirm every signer is expected."))
        }
        if actions.contains(where: { $0.localizedCaseInsensitiveContains("Token Transfer") || $0.localizedCaseInsensitiveContains("TransferChecked") }) {
            flags.append(.init(kind: .tokenTransfer, level: .medium, message: "Token transfer instruction is present. Confirm token, amount, and recipient in the destination flow."))
        }
        if actions.contains(where: { $0.localizedCaseInsensitiveContains("System transfer") }) {
            flags.append(.init(kind: .nativeSOLTransfer, level: .medium, message: "Native SOL transfer instruction is present. Confirm SOL movement and rent effects."))
        }
        if actions.contains(where: { $0.localizedCaseInsensitiveContains("Set authority") }) {
            flags.append(.init(kind: .authorityChange, level: .high, message: "Authority change instruction is present. This can alter control over a token account or mint."))
        }
        if actions.contains(where: { $0.localizedCaseInsensitiveContains("Close token account") }) {
            flags.append(.init(kind: .closeAccount, level: .medium, message: "Close-account instruction is present. Confirm account closure and rent destination."))
        }
        if actions.contains(where: { $0.localizedCaseInsensitiveContains("Approve") }) {
            flags.append(.init(kind: .approveDelegate, level: .high, message: "Token delegate approval is present. Review allowance and delegate carefully."))
        }
        if programLabels.contains("Token-2022") {
            flags.append(.init(kind: .token2022TransferHook, level: .medium, message: "Token-2022 program is present. Extensions such as transfer hooks may affect execution."))
            flags.append(.init(kind: .token2022TransferFee, level: .medium, message: "Token-2022 program is present. Transfer fees may apply if configured by the mint."))
        }
        if programLabels.contains("Upgradeable Loader") {
            flags.append(.init(kind: .upgradeableProgramInteraction, level: .medium, message: "Upgradeable loader interaction is present. Confirm program-management intent."))
        }
        if decoded.addressLookupTables.isEmpty == false {
            flags.append(.init(kind: .addressLookupTableUse, level: .medium, message: "Versioned transaction uses \(decoded.addressLookupTables.count) address lookup table(s). Loaded addresses are summarized, not fully expanded."))
        }
        if let units = simulation.unitsConsumed, units >= highComputeUnitThreshold {
            flags.append(.init(kind: .highComputeUsage, level: .medium, message: "Simulation consumed \(units) compute units, which is high."))
        }
        switch simulation.status {
        case .failed:
            flags.append(.init(kind: .simulationFailed, level: .high, message: simulation.errorMessage ?? "Simulation failed. Do not approve until resolved."))
        case .notRun, .unavailable:
            flags.append(.init(kind: .missingSimulation, level: .unknown, message: simulation.errorMessage ?? "Simulation is missing or unavailable. Review remains incomplete."))
        case .success:
            break
        }
        if decoded.network.isMainnet {
            flags.append(.init(kind: .mainnetTransaction, level: .medium, message: "This is a mainnet transaction. Any approval in a destination module can affect real funds."))
        }
        if programLabels.contains("Cloak") {
            flags.append(.init(kind: .privateCloakProgramInteraction, level: .high, message: "Cloak private program interaction is present. Review private-state requirements in Wallet -> Private."))
        }
        if programLabels.intersection(["Jupiter", "Orca Whirlpool", "Raydium AMM", "Raydium CPMM", "Raydium CLMM", "Meteora DLMM", "Kamino", "MarginFi"]).isEmpty == false {
            flags.append(.init(kind: .defiProtocolInteraction, level: .medium, message: "DeFi protocol interaction is present. Confirm route, market, and protocol risk."))
        }

        let level: TransactionRiskLevel
        if flags.contains(where: { $0.level == .high }) {
            level = .high
        } else if flags.contains(where: { $0.level == .medium }) {
            level = .medium
        } else if flags.contains(where: { $0.level == .unknown }) {
            level = .unknown
        } else {
            level = .low
        }
        return TransactionRiskReview(level: level, flags: flags, generatedAt: Date())
    }
}
