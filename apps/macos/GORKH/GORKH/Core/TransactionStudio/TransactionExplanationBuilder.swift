import Foundation

enum TransactionExplanationBuilder {
    static func build(
        decoded: DecodedTransaction?,
        simulation: TransactionStudioSimulationSummary,
        risk: TransactionRiskReview,
        addressSummary: TransactionStudioAddressSummary? = nil
    ) -> TransactionExplanation {
        if let addressSummary {
            return TransactionExplanation(
                summary: "Address \(short(addressSummary.address)) is owned by \(addressSummary.ownerLabel ?? "an unknown program"). It has \(addressSummary.lamports.map(String.init) ?? "unknown") lamports and \(addressSummary.dataLength.map(String.init) ?? "unknown") bytes of data.",
                reviewChecklist: [
                    addressSummary.executable == true ? "Executable account: confirm this is a program address." : "Non-executable account.",
                    addressSummary.tokenAccountSummary ?? "No parsed token account summary available.",
                    addressSummary.warning ?? "No address warning generated."
                ],
                source: "local deterministic",
                generatedAt: Date()
            )
        }

        guard let decoded else {
            return TransactionExplanation(
                summary: "No transaction has been decoded yet. Paste a signature or raw transaction to inspect it.",
                reviewChecklist: ["Transaction Studio v0.1 cannot sign or broadcast."],
                source: "local deterministic",
                generatedAt: Date()
            )
        }

        let programList = decoded.programSummaries.map { $0.label }.joined(separator: ", ")
        let signerText = decoded.signerSummaries.map { short($0.address) }.joined(separator: ", ")
        let simText: String
        switch simulation.status {
        case .success:
            simText = "Simulation passed."
        case .failed:
            simText = "Simulation failed."
        case .unavailable:
            simText = "Simulation is unavailable."
        case .notRun:
            simText = "Simulation has not run."
        }
        let altSummary: String
        if decoded.addressLookupTables.isEmpty {
            altSummary = "No address lookup tables are referenced."
        } else {
            altSummary = "It references \(decoded.addressLookupOverview.tableCount) address lookup table(s), with \(decoded.addressLookupOverview.loadedWritableCount) loaded writable and \(decoded.addressLookupOverview.loadedReadonlyCount) loaded readonly address(es) available from RPC."
        }
        let diffSummary: String
        switch simulation.accountDiff.status {
        case .available:
            diffSummary = "Account diff is available for \(simulation.accountDiff.rows.count) watched account(s)."
        case .unavailable:
            diffSummary = "Account diff is unavailable."
        case .notRequested:
            diffSummary = "Account diff has not been requested."
        }
        let summary = "This \(decoded.transactionVersion) transaction uses \(decoded.instructions.count) instruction(s) across \(decoded.programSummaries.count) program(s): \(programList.isEmpty ? "none detected" : programList). Required signer(s): \(signerText.isEmpty ? "none detected" : signerText). \(altSummary) \(simText) \(diffSummary)"
        let recognizedFragments = decoded.instructions
            .compactMap(\.parsedSummary.explanationFragment)
            .removingDuplicates()
            .prefix(4)
        let parserSummary: String
        if recognizedFragments.isEmpty {
            parserSummary = "No common instruction parser produced a detailed action summary."
        } else {
            parserSummary = "Recognized actions: \(recognizedFragments.joined(separator: " "))"
        }
        let unknownCount = decoded.instructions.filter { $0.parseStatus == .unknown }.count
        let unknownSummary = unknownCount > 0 ? " \(unknownCount) instruction(s) remain unknown and require caution." : ""

        var checklist = [
            "Confirm fee payer \(decoded.feePayer.map(short) ?? "unknown") is expected.",
            "Review every writable account before approving in any destination module.",
            decoded.addressLookupTables.isEmpty ? "No ALT review needed for this transaction." : "Review lookup-table loaded addresses and unresolved ALT state.",
            simulation.accountDiff.status == .available ? "Review account diff rows for lamport, token, owner, created, or closed changes." : "Account diff is unavailable; do not infer balance movement from instruction labels alone.",
            "Check simulation logs and error state before approval.",
            "Transaction Studio does not sign, broadcast, or move funds."
        ]
        checklist.append(contentsOf: risk.flags.prefix(5).map(\.message))

        return TransactionExplanation(
            summary: "\(summary) \(parserSummary)\(unknownSummary)",
            reviewChecklist: checklist,
            source: "local deterministic",
            generatedAt: Date()
        )
    }

    nonisolated private static func short(_ value: String) -> String {
        guard value.count > 12 else {
            return value
        }
        return "\(value.prefix(4))...\(value.suffix(4))"
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
