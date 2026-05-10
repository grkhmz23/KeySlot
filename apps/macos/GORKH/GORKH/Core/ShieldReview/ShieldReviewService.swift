import Foundation

enum ShieldReviewService {
    static func review(decoded: DecodedTransaction, simulation: TransactionStudioSimulationSummary) -> ShieldReviewSummary {
        let risk = TransactionRiskAnalyzer.review(decoded: decoded, simulation: simulation)
        let explanation = TransactionExplanationBuilder.build(decoded: decoded, simulation: simulation, risk: risk)
        let actions = decoded.instructions.map {
            ShieldReviewParsedAction(
                label: $0.decodedAction,
                detail: $0.parsedSummary.details.map { "\($0.label): \($0.value)" }.joined(separator: ", "),
                assetMovement: assetMovementText(from: $0.parsedSummary)
            )
        }
        return ShieldReviewSummary(
            title: "Transaction Studio Shield Review",
            status: .ready,
            riskLevel: ShieldReviewRiskLevel(risk.level),
            parsedActions: actions,
            programLabels: decoded.programSummaries.map(\.label).removingDuplicates(),
            signerCount: decoded.signerSummaries.count,
            writableCount: decoded.writableAccounts.count,
            unknownInstructionCount: decoded.instructions.filter { $0.parseStatus == .unknown }.count,
            riskFlags: risk.flags.map { ShieldReviewRiskFlag(kind: $0.kind.rawValue, level: ShieldReviewRiskLevel($0.level), message: $0.message) },
            simulation: ShieldReviewSimulationSummary(
                status: ShieldReviewSimulationStatus(simulation),
                computeUnits: simulation.unitsConsumed,
                estimatedFeeLamports: nil,
                errorMessage: simulation.errorMessage,
                logPreview: Array(simulation.logs.prefix(8))
            ),
            explanation: explanation.summary,
            approvalRequirements: [.review, .simulation, .explicitApproval, .destinationApproval],
            handoff: handoff(
                title: "Transaction Studio Shield Review",
                status: .ready,
                riskLevel: ShieldReviewRiskLevel(risk.level),
                programs: decoded.programSummaries.map(\.label),
                actions: actions,
                signerCount: decoded.signerSummaries.count,
                writableCount: decoded.writableAccounts.count,
                unknownCount: decoded.instructions.filter { $0.parseStatus == .unknown }.count,
                simulation: ShieldReviewSimulationStatus(simulation),
                riskMessages: risk.flags.map(\.message),
                temporaryRawPayloadAvailable: false
            )
        )
    }

    static func reviewRawTransactionBase64(_ base64: String, network: WalletNetwork, simulation: SimulationResult?) -> ShieldReviewSummary {
        guard let data = Data(base64Encoded: base64) else {
            return .unavailable(
                title: "Shield Review",
                reason: "Transaction bytes were not valid base64.",
                requirements: [.review, .simulation, .explicitApproval, .destinationApproval]
            )
        }
        do {
            let decoded = try TransactionDecoder.decode(
                data: data,
                inputKind: .importHandoff,
                fetchedSignature: nil,
                slot: nil,
                blockTime: nil,
                network: network
            )
            let studioSimulation = studioSimulation(from: simulation)
            return review(decoded: decoded, simulation: studioSimulation)
        } catch {
            return .unavailable(
                title: "Shield Review",
                reason: "Transaction decode unavailable: \(error.localizedDescription)",
                requirements: [.review, .simulation, .explicitApproval, .destinationApproval]
            )
        }
    }

    static func reviewSOLTransfer(draft: TransactionDraft, simulation: SimulationResult?) -> ShieldReviewSummary {
        let action = ShieldReviewParsedAction(
            label: "System transfer",
            detail: "Transfer \(draft.amountSOLText) from \(draft.fromAddress.shortAddress) to \(draft.toAddress.shortAddress).",
            assetMovement: "\(draft.amountSOLText) may move to \(draft.toAddress.shortAddress)."
        )
        var flags = [
            ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.nativeSOLTransfer.rawValue, level: .medium, message: "Native SOL transfer instruction is expected. Confirm recipient and amount."),
            mainnetFlagIfNeeded(network: draft.network)
        ].compactMap { $0 }
        flags.append(contentsOf: simulationFlags(simulation))
        return summary(
            title: "SOL Send Shield Review",
            riskLevel: riskLevel(flags: flags, defaultLevel: draft.network.isMainnet ? .medium : .low),
            actions: [action],
            programs: [TransactionProgramCatalog.entry(for: SolanaConstants.systemProgramID).label],
            signerCount: 1,
            writableCount: 2,
            unknownCount: 0,
            riskFlags: flags,
            simulation: ShieldReviewSimulationSummary(simulation),
            explanation: "This approval prepares a System Program SOL transfer. Review the recipient, amount, fee estimate, simulation result, and mainnet phrase before signing.",
            requirements: [.review, .simulation, .explicitApproval, .localAuthentication, .nativeSigner, .destinationApproval]
                + (draft.network.isMainnet ? [.mainnetPhrase] : [])
        )
    }

    static func reviewTokenTransfer(draft: TokenTransferDraft, simulation: SimulationResult?) -> ShieldReviewSummary {
        var actions: [ShieldReviewParsedAction] = []
        if draft.ataPlan.shouldCreateAssociatedTokenAccount {
            actions.append(ShieldReviewParsedAction(
                label: "Create associated token account",
                detail: "Create recipient token account \(draft.recipientTokenAccount?.shortAddress ?? "unavailable") for owner \(draft.recipientOwnerAddress.shortAddress).",
                assetMovement: draft.ataPlan.rentExemptLamports.map { "Sender may pay \($0) lamports rent for ATA creation." }
            ))
        }
        actions.append(ShieldReviewParsedAction(
            label: "Token transferChecked",
            detail: "Transfer \(draft.formattedAmount) \(draft.tokenDisplayName) (\(draft.amountRaw) raw) to \(draft.recipientOwnerAddress.shortAddress).",
            assetMovement: "\(draft.formattedAmount) \(draft.tokenDisplayName) may move from source token account \(draft.sourceTokenAccount.shortAddress)."
        ))

        var flags: [ShieldReviewRiskFlag] = [
            ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.tokenTransfer.rawValue, level: .medium, message: "Token transfer instruction is expected. Confirm mint, recipient owner, and amount.")
        ]
        if draft.tokenProgramKind == .token2022 {
            flags.append(ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.token2022TransferHook.rawValue, level: .medium, message: "Token-2022 transfer hooks may affect execution if configured by the mint."))
            flags.append(ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.token2022TransferFee.rawValue, level: .medium, message: "Token-2022 transfer fees may apply if configured by the mint."))
        }
        if draft.ataPlan.shouldCreateAssociatedTokenAccount {
            flags.append(ShieldReviewRiskFlag(kind: "associated_token_account_create", level: .low, message: "Recipient associated token account creation is included. Sender pays rent/fees."))
        }
        flags.append(contentsOf: draft.warnings.map { warning in
            ShieldReviewRiskFlag(kind: "token_warning", level: warning.blocksSend ? .high : .medium, message: warning.message)
        })
        if let flag = mainnetFlagIfNeeded(network: draft.network) {
            flags.append(flag)
        }
        flags.append(contentsOf: simulationFlags(simulation))

        let programs = ([draft.tokenProgramKind.displayName] + (draft.ataPlan.shouldCreateAssociatedTokenAccount ? [TransactionProgramCatalog.entry(for: SolanaConstants.associatedTokenAccountProgramID).label] : [])).removingDuplicates()
        return summary(
            title: "Token Send Shield Review",
            riskLevel: riskLevel(flags: flags, defaultLevel: draft.network.isMainnet ? .medium : .low),
            actions: actions,
            programs: programs,
            signerCount: 1,
            writableCount: draft.ataPlan.shouldCreateAssociatedTokenAccount ? 6 : 3,
            unknownCount: 0,
            riskFlags: flags,
            simulation: ShieldReviewSimulationSummary(simulation),
            explanation: "This approval prepares a token transfer. Review token mint, program, source token account, recipient owner, ATA creation state, amount, and simulation before signing.",
            requirements: [.review, .simulation, .explicitApproval, .localAuthentication, .nativeSigner, .destinationApproval]
                + (draft.network.isMainnet ? [.mainnetPhrase] : [])
        )
    }

    static func reviewSwap(quote: JupiterQuoteSummary?, review: SwapTransactionReview?, simulation: SimulationResult?, network: WalletNetwork) -> ShieldReviewSummary {
        guard let quote else {
            return .unavailable(title: "Swap Shield Review", reason: "Jupiter quote is missing.", requirements: [.review, .simulation, .explicitApproval, .destinationApproval])
        }
        let routeLabels = quote.routePlan.map(\.label).removingDuplicates()
        let action = ShieldReviewParsedAction(
            label: "Jupiter swap route",
            detail: "Swap \(quote.inAmount) raw \(quote.inputMint.shortAddress) for at least \(quote.otherAmountThreshold) raw \(quote.outputMint.shortAddress). Route: \(quote.routeLabel).",
            assetMovement: "Input token may decrease and output token may increase after route execution."
        )

        var flags = [
            ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.defiProtocolInteraction.rawValue, level: .medium, message: "Jupiter aggregator route is present. Verify route, tokens, slippage, and minimum received."),
            review?.addressLookupTableCount ?? 0 > 0 ? ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.addressLookupTableUse.rawValue, level: .medium, message: "Swap transaction uses \(review?.addressLookupTableCount ?? 0) address lookup table(s). Review route accounts and simulation.") : nil,
            mainnetFlagIfNeeded(network: network)
        ].compactMap { $0 }
        flags.append(contentsOf: review?.riskWarnings.map { warning in
            ShieldReviewRiskFlag(kind: "swap_route_warning", level: shieldLevel(for: warning.severity), message: warning.message)
        } ?? [])
        flags.append(contentsOf: simulationFlags(simulation))

        let programs = (review?.programSummaries.map(\.label) ?? ["Jupiter"]) + routeLabels
        return summary(
            title: "Jupiter Swap Shield Review",
            riskLevel: riskLevel(flags: flags, defaultLevel: .medium),
            actions: [action],
            programs: programs.removingDuplicates(),
            signerCount: review?.signerAccounts.count ?? 1,
            writableCount: review?.writableAccounts.count ?? 0,
            unknownCount: review == nil ? 1 : 0,
            riskFlags: flags,
            simulation: ShieldReviewSimulationSummary(simulation),
            explanation: "This approval prepares a Jupiter swap. Review quote freshness, route, token mints, minimum received, writable accounts, ALT use, and simulation before signing.",
            requirements: [.review, .simulation, .explicitApproval, .localAuthentication, .nativeSigner, .destinationApproval, .mainnetPhrase]
        )
    }

    static func reviewOrcaHarvest(draft: OrcaHarvestDraft?, review: OrcaHarvestReview?, simulation: SimulationResult?) -> ShieldReviewSummary {
        guard let draft else {
            return .unavailable(title: "Orca Harvest Shield Review", reason: "Orca harvest draft is missing.", requirements: [.review, .simulation, .explicitApproval, .destinationApproval])
        }
        let action = ShieldReviewParsedAction(
            label: "Orca harvest fees/rewards",
            detail: "Harvest position \(draft.positionMint.shortAddress) in pool \(draft.poolAddress.shortAddress).",
            assetMovement: "Fees or rewards may be collected to wallet-associated token accounts if simulation and approval pass."
        )
        var flags: [ShieldReviewRiskFlag] = [
            ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.defiProtocolInteraction.rawValue, level: .medium, message: "Orca Whirlpool protocol interaction. Review instruction count, writable accounts, and simulation logs.")
        ]
        flags.append(contentsOf: review?.warnings.map {
            ShieldReviewRiskFlag(kind: "orca_harvest_warning", level: .medium, message: $0)
        } ?? [])
        flags.append(contentsOf: review?.blockingReasons.map {
            ShieldReviewRiskFlag(kind: "orca_harvest_blocking_reason", level: .high, message: $0)
        } ?? [])
        flags.append(contentsOf: simulationFlags(simulation))
        if let flag = mainnetFlagIfNeeded(network: draft.network) {
            flags.append(flag)
        }

        return summary(
            title: "Orca Harvest Shield Review",
            riskLevel: riskLevel(flags: flags, defaultLevel: .medium),
            actions: [action],
            programs: (review?.baseReview.programSummaries.map(\.label) ?? ["Orca Whirlpool"]).removingDuplicates(),
            signerCount: review?.baseReview.signerAccounts.count ?? 1,
            writableCount: review?.writableAccountCount ?? draft.plan.writableAccountCount,
            unknownCount: review?.unknownProgramIDs.count ?? 0,
            riskFlags: flags,
            simulation: ShieldReviewSimulationSummary(simulation),
            explanation: "This approval prepares an Orca harvest. If exact instruction data is not fully decoded, treat it as a protocol interaction and review simulation logs before signing.",
            requirements: [.review, .simulation, .explicitApproval, .localAuthentication, .nativeSigner, .destinationApproval, .mainnetPhrase]
        )
    }

    static func reviewCloakDeposit(draft: CloakDepositDraft?) -> ShieldReviewSummary {
        guard let draft else {
            return .unavailable(title: "Cloak Shield Review", reason: "Cloak deposit draft is missing.", requirements: [.review, .explicitApproval, .localAuthentication, .nativeSigner, .mainnetPhrase])
        }
        let action = ShieldReviewParsedAction(
            label: "Cloak deposit",
            detail: "Shield \(draft.feeQuote.grossSOLText) from \(draft.sourceWalletAddress.shortAddress).",
            assetMovement: "SOL may move into the Cloak program after destination approval."
        )
        let flags = [
            ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.privateCloakProgramInteraction.rawValue, level: .high, message: "Cloak private program interaction. Confirm local private-state storage and recovery limitations."),
            mainnetFlagIfNeeded(network: draft.network)
        ].compactMap { $0 }
        return summary(
            title: "Cloak Deposit Shield Review",
            riskLevel: .high,
            actions: [action],
            programs: ["Cloak"],
            signerCount: 1,
            writableCount: 0,
            unknownCount: 0,
            riskFlags: flags,
            simulation: .notRun,
            explanation: "Raw Cloak transaction bytes are not exposed in this approval panel. GORKH preserves the existing Cloak approval gates and does not expose private state or vault internals.",
            requirements: [.review, .explicitApproval, .localAuthentication, .nativeSigner, .mainnetPhrase, .destinationApproval]
        )
    }

    static func reviewCloakFullWithdraw(record: CloakPrivateRecordMetadata?, recipientAddress: String) -> ShieldReviewSummary {
        guard let record else {
            return .unavailable(title: "Cloak Full Withdraw Shield Review", reason: "No local Cloak record is selected.", requirements: [.review, .explicitApproval, .localAuthentication, .nativeSigner, .mainnetPhrase])
        }
        let action = ShieldReviewParsedAction(
            label: "Cloak full withdraw",
            detail: "Spend local private record \(record.shortCommitment) to recipient \(recipientAddress.shortAddress).",
            assetMovement: "Private SOL may be withdrawn to the public recipient after destination approval."
        )
        return summary(
            title: "Cloak Full Withdraw Shield Review",
            riskLevel: .high,
            actions: [action],
            programs: ["Cloak"],
            signerCount: 1,
            writableCount: 0,
            unknownCount: 0,
            riskFlags: [
                ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.privateCloakProgramInteraction.rawValue, level: .high, message: "Cloak private program interaction. This spends local private state after explicit approval."),
                ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.mainnetTransaction.rawValue, level: .medium, message: "Cloak full withdraw is mainnet-only.")
            ],
            simulation: .notRun,
            explanation: "Raw Cloak transaction bytes and private inputs are not shown here. Review fee, recipient, local vault state, and exact mainnet phrase before signing.",
            requirements: [.review, .explicitApproval, .localAuthentication, .nativeSigner, .mainnetPhrase, .destinationApproval]
        )
    }

    static func reviewZerionTinySwap(proposal: ZerionTinySwapProposal, decision: ZerionExecutionPolicyDecision, commandPlan: ZerionSwapCommandPlan?) -> ShieldReviewSummary {
        let action = ShieldReviewParsedAction(
            label: "External Zerion tiny swap",
            detail: "\(proposal.chain.label): \(NSDecimalNumber(decimal: proposal.amount).stringValue) \(proposal.fromToken) to \(proposal.toToken).",
            assetMovement: "Execution uses the separate Zerion wallet, not the GORKH main wallet."
        )
        var flags = [
            ShieldReviewRiskFlag(kind: "zerion_external_summary", level: .medium, message: "External Zerion execution summary; raw transaction decode unavailable."),
            ShieldReviewRiskFlag(kind: "zerion_separate_wallet", level: .low, message: "GORKH main-wallet signer is not used."),
            ShieldReviewRiskFlag(kind: "zerion_policy", level: decision.canExecute ? .low : .high, message: decision.canExecute ? "Local Zerion policy check passed." : "Local Zerion policy check blocks execution.")
        ]
        flags.append(contentsOf: decision.blockingReasons.map {
            ShieldReviewRiskFlag(kind: "zerion_policy_block", level: .high, message: $0)
        })
        flags.append(contentsOf: decision.warnings.map {
            ShieldReviewRiskFlag(kind: "zerion_policy_warning", level: .medium, message: $0)
        })

        let commandPreview = commandPlan?.redactedPreview ?? "Command preview unavailable"
        return summary(
            title: "Zerion Tiny Swap Shield Review",
            status: .externalSummary,
            riskLevel: riskLevel(flags: flags, defaultLevel: .medium),
            actions: [action],
            programs: ["Zerion CLI"],
            signerCount: 0,
            writableCount: 0,
            unknownCount: 1,
            riskFlags: flags,
            simulation: .notRun,
            explanation: "External Zerion execution summary; raw transaction decode unavailable. GORKH does not receive raw Solana transaction bytes and does not fake a decode. Preview: \(commandPreview)",
            requirements: [.review, .explicitApproval, .destinationApproval],
            temporaryRawPayloadAvailable: false
        )
    }

    private static func summary(
        title: String,
        status: ShieldReviewStatus = .ready,
        riskLevel: ShieldReviewRiskLevel,
        actions: [ShieldReviewParsedAction],
        programs: [String],
        signerCount: Int,
        writableCount: Int,
        unknownCount: Int,
        riskFlags: [ShieldReviewRiskFlag],
        simulation: ShieldReviewSimulationSummary,
        explanation: String,
        requirements: [ShieldReviewApprovalRequirement],
        temporaryRawPayloadAvailable: Bool = false
    ) -> ShieldReviewSummary {
        ShieldReviewSummary(
            title: title,
            status: status,
            riskLevel: riskLevel,
            parsedActions: actions,
            programLabels: programs.removingDuplicates(),
            signerCount: signerCount,
            writableCount: writableCount,
            unknownInstructionCount: unknownCount,
            riskFlags: riskFlags,
            simulation: simulation,
            explanation: explanation,
            approvalRequirements: requirements.removingDuplicates(),
            handoff: handoff(
                title: title,
                status: status,
                riskLevel: riskLevel,
                programs: programs,
                actions: actions,
                signerCount: signerCount,
                writableCount: writableCount,
                unknownCount: unknownCount,
                simulation: simulation.status,
                riskMessages: riskFlags.map(\.message),
                temporaryRawPayloadAvailable: temporaryRawPayloadAvailable
            )
        )
    }

    private static func handoff(
        title: String,
        status: ShieldReviewStatus,
        riskLevel: ShieldReviewRiskLevel,
        programs: [String],
        actions: [ShieldReviewParsedAction],
        signerCount: Int,
        writableCount: Int,
        unknownCount: Int,
        simulation: ShieldReviewSimulationStatus,
        riskMessages: [String],
        temporaryRawPayloadAvailable: Bool
    ) -> ShieldReviewHandoff {
        let temporaryNote = temporaryRawPayloadAvailable
            ? "A temporary in-memory payload may be available to the destination view; it is not persisted by Shield Review."
            : "Safe summary only; no raw transaction payload is persisted."
        let summary = [
            "Shield Review: \(title)",
            "Status: \(status.title)",
            "Risk: \(riskLevel.title)",
            "Simulation: \(simulation.title)",
            "Programs: \(programs.removingDuplicates().joined(separator: ", "))",
            "Actions: \(actions.map(\.label).joined(separator: ", "))",
            "Signers: \(signerCount)",
            "Writable accounts: \(writableCount)",
            "Unknown instructions: \(unknownCount)",
            "Risk flags: \(riskMessages.joined(separator: " | "))",
            temporaryNote,
            "Transaction Studio cannot sign or broadcast."
        ].joined(separator: "\n")
        return ShieldReviewHandoff(
            safeSummary: summary,
            temporaryRawPayloadAvailable: temporaryRawPayloadAvailable,
            note: temporaryNote
        )
    }

    private static func assetMovementText(from parsed: TransactionParsedInstruction) -> String? {
        parsed.details.first { $0.label.localizedCaseInsensitiveContains("amount") }?.value
    }

    private static func studioSimulation(from simulation: SimulationResult?) -> TransactionStudioSimulationSummary {
        guard let simulation else {
            return .notRun
        }
        let status: TransactionStudioSimulationStatus
        switch simulation.status {
        case .success:
            status = .success
        case .failed:
            status = .failed
        case .unavailable:
            status = .unavailable
        }
        return TransactionStudioSimulationSummary(
            status: status,
            logs: simulation.logs,
            unitsConsumed: nil,
            errorMessage: simulation.errorMessage,
            replacementBlockhashUsed: false,
            simulatedAt: simulation.simulatedAt
        )
    }

    private static func simulationFlags(_ simulation: SimulationResult?) -> [ShieldReviewRiskFlag] {
        guard let simulation else {
            return [
                ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.missingSimulation.rawValue, level: .unknown, message: "Simulation has not run.")
            ]
        }
        switch simulation.status {
        case .success:
            return []
        case .failed:
            return [
                ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.simulationFailed.rawValue, level: .high, message: simulation.errorMessage ?? "Simulation failed.")
            ]
        case .unavailable:
            return [
                ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.missingSimulation.rawValue, level: .unknown, message: simulation.errorMessage ?? "Simulation is unavailable.")
            ]
        }
    }

    private static func mainnetFlagIfNeeded(network: WalletNetwork) -> ShieldReviewRiskFlag? {
        guard network.isMainnet else {
            return nil
        }
        return ShieldReviewRiskFlag(kind: TransactionRiskFlagKind.mainnetTransaction.rawValue, level: .medium, message: "This is a real mainnet approval flow.")
    }

    private static func riskLevel(flags: [ShieldReviewRiskFlag], defaultLevel: ShieldReviewRiskLevel) -> ShieldReviewRiskLevel {
        if flags.contains(where: { $0.level == .high }) {
            return .high
        }
        if flags.contains(where: { $0.level == .medium }) {
            return .medium
        }
        if flags.contains(where: { $0.level == .unknown }) {
            return .unknown
        }
        return defaultLevel
    }

    private static func shieldLevel(for severity: SwapRouteRiskSeverity) -> ShieldReviewRiskLevel {
        switch severity {
        case .info:
            return .low
        case .warning:
            return .medium
        case .high:
            return .high
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
