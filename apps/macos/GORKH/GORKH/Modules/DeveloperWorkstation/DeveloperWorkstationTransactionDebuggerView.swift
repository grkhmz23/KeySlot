import SwiftUI

struct DeveloperWorkstationTransactionDebuggerView: View {
    let selectedCluster: WorkstationCluster
    let parsedIDL: WorkstationIDL?
    let currentProjectBrain: DeveloperProjectBrain?
    let report: TransactionDebugReport?
    let evidence: [TransactionDebugReport]
    let status: WorkstationDataStatus
    let message: String
    let isDebugging: Bool
    let isFetchingAccountDetails: Bool
    let dateFormatter: DateFormatter
    @Binding var signature: String
    @Binding var idlSelection: String
    @Binding var pane: TransactionDebugPane
    @Binding var logFilter: String
    let onFetchDebug: () -> Void
    let onFetchAccountDetails: () -> Void
    let onOpenSecurityScanner: () -> Void
    let onRecordDebugReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let report {
                summaryCards(report)
                paneSelector
                paneContent(report)
            } else {
                GorkhPanel("No Debug Report") {
                    Text("Paste a transaction signature and select Fetch & Debug. Mainnet is supported only for read-only transaction inspection when the configured RPC endpoint allows it.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var header: some View {
        GorkhPanel("Transaction Debugger") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RPC/log-based debugger using read-only `getTransaction`. Root-cause suggestions are heuristic unless deterministic evidence is available; custom error mapping requires a matching loaded IDL.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            WorkstationStatusChip(title: "Read-only", systemImage: "eye", color: GorkhColors.success)
                            WorkstationStatusChip(title: "No signing", systemImage: "lock.shield", color: GorkhColors.success)
                            WorkstationStatusChip(title: selectedCluster.title, systemImage: selectedCluster.isMainnet ? "globe" : "server.rack", color: selectedCluster.isMainnet ? GorkhColors.warning : GorkhColors.success)
                        }
                    }

                    Spacer()

                    Button(isDebugging ? "Fetching..." : "Fetch & Debug") {
                        onFetchDebug()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDebugging || signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                DeveloperWorkstationLabeledTextField(label: "Transaction signature", text: $signature, prompt: "64-byte base58 signature")

                HStack(spacing: 10) {
                    Picker("IDL", selection: $idlSelection) {
                        Text(parsedIDL == nil ? "No loaded IDL" : "Loaded IDL: \(parsedIDL?.name ?? "IDL")").tag("__loaded")
                        Text("No IDL mapping").tag("__none")
                        ForEach(currentProjectBrain?.idls ?? []) { idl in
                            Text(idl.relativePath).tag(idl.relativePath)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 320)

                    WorkstationStatusChip(
                        title: status.title,
                        systemImage: status == .ready ? "checkmark.circle" : "exclamationmark.triangle",
                        color: statusColor(status)
                    )

                    Spacer()
                }

                Text(message)
                    .font(.caption)
                    .foregroundStyle(status == .error ? GorkhColors.warning : GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("This page never calls write RPC methods, never signs, and never broadcasts. Account owner/lamport details are fetched only after you press the account-detail button.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summaryCards(_ report: TransactionDebugReport) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
            overviewCard("Status", value: report.status.title, detail: report.err ?? report.likelyRootCause)
            overviewCard("Slot", value: report.slot.map(String.init) ?? "Unavailable", detail: report.blockTime.map { dateFormatter.string(from: $0) } ?? "No block time")
            overviewCard("Fee", value: report.fee.map { "\($0) lamports" } ?? "Unavailable", detail: report.shortSignature)
            overviewCard("Programs", value: "\(report.programIds.count)", detail: fallback(report.programIds.map(TransactionInstructionLabeler.label(for:)).joined(separator: ", "), "No programs"))
            overviewCard("Instructions", value: "\(report.topLevelInstructions.count)", detail: "\(report.innerInstructions.count) inner")
            overviewCard("Compute", value: report.computeUnits.map(String.init) ?? "Unavailable", detail: "\(report.computeTimeline.count) compute log(s)")
            overviewCard("Accounts", value: "\(report.accountTable.count)", detail: "\(report.accountTable.filter(\.isWritable).count) writable")
            overviewCard("PDA checks", value: "\(report.pdaMismatchCandidates.count)", detail: report.pdaMismatchCandidates.first?.reason ?? "No mismatches found")
        }
    }

    private var paneSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TransactionDebugPane.allCases) { item in
                    Button {
                        pane = item
                    } label: {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(pane == item ? .white : GorkhColors.secondaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(pane == item ? GorkhColors.accent : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(pane == item ? GorkhColors.accent.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func paneContent(_ report: TransactionDebugReport) -> some View {
        switch pane {
        case .summary:
            transactionDebugSummary(report)
        case .instructionTree:
            transactionDebugInstructionTree(report)
        case .logs:
            transactionDebugLogs(report)
        case .accounts:
            transactionDebugAccounts(report)
        case .compute:
            transactionDebugCompute(report)
        case .errorMapping:
            transactionDebugErrorMapping(report)
        case .pdaChecks:
            transactionDebugPDAChecks(report)
        case .evidence:
            transactionDebugEvidenceView(report)
        }
    }

    private func transactionDebugSummary(_ report: TransactionDebugReport) -> some View {
        GorkhPanel("Summary") {
            WorkstationStatusChip(
                title: report.status.title,
                systemImage: report.status == .success ? "checkmark.circle" : "exclamationmark.triangle",
                color: report.status == .success ? GorkhColors.success : GorkhColors.warning
            )
            keyValue("Signature", report.signature)
            keyValue("Cluster", report.cluster.title)
            keyValue("Fetched", dateFormatter.string(from: report.fetchedAt))
            keyValue("Likely root cause", report.likelyRootCause)
            keyValue("Replay support", report.replaySupportStatus)
            DisclosureGroup("Suggested next steps") {
                ForEach(report.suggestedNextSteps, id: \.self) { step in
                    Text(step)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            DisclosureGroup("Programs") {
                ForEach(report.programIds, id: \.self) { programID in
                    keyValue(TransactionInstructionLabeler.label(for: programID), programID)
                }
            }
            Button("Open Security Scanner") {
                onOpenSecurityScanner()
            }
            .buttonStyle(.bordered)
        }
    }

    private func transactionDebugInstructionTree(_ report: TransactionDebugReport) -> some View {
        GorkhPanel("Instruction Tree") {
            if report.topLevelInstructions.isEmpty {
                Text("No decoded instruction tree is available for this report.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(report.topLevelInstructions) { node in
                instructionDebugNodeView(node)
            }
        }
    }

    private func instructionDebugNodeView(_ node: InstructionDebugNode) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                WorkstationStatusChip(
                    title: node.errorAtThisInstruction ? "Error" : "Instruction \(node.index)",
                    systemImage: node.errorAtThisInstruction ? "exclamationmark.triangle" : "list.bullet.rectangle",
                    color: node.errorAtThisInstruction ? GorkhColors.warning : GorkhColors.success
                )
                Text(node.programName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
            }
            Text(node.instructionName)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            keyValue("Program", node.programID)
            keyValue("Accounts", "\(node.accounts.count)")
            if let compute = node.computeUnitsConsumed {
                keyValue("Compute", "\(compute) units")
            }
            if !node.signerWritableHints.isEmpty {
                DisclosureGroup("Signer / writable hints") {
                    ForEach(node.signerWritableHints, id: \.self) { hint in
                        DeveloperWorkstationScrollingMonospacedText(value: hint)
                    }
                }
            }
            if !node.logs.isEmpty {
                DisclosureGroup("Relevant logs") {
                    ForEach(Array(node.logs.enumerated()), id: \.offset) { _, line in
                        DeveloperWorkstationScrollingMonospacedText(value: line)
                    }
                }
            }
            if !node.innerInstructions.isEmpty {
                DisclosureGroup("Inner instructions") {
                    ForEach(node.innerInstructions) { inner in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(inner.programName) · \(inner.instructionName)")
                                .font(.caption)
                                .fontWeight(.semibold)
                            keyValue("Program", inner.programID)
                            keyValue("Accounts", "\(inner.accounts.count)")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func transactionDebugLogs(_ report: TransactionDebugReport) -> some View {
        GorkhPanel("Logs") {
            DeveloperWorkstationLabeledTextField(label: "Filter", text: $logFilter, prompt: "error, program id, compute...")
            keyValue("Log lines", "\(report.logSummary.totalLines)")
            keyValue("Error lines", "\(report.logSummary.errorLineCount)")
            keyValue("Compute lines", "\(report.logSummary.computeLineCount)")
            if let failedProgram = report.logSummary.failedProgramID {
                keyValue("Failed program", "\(TransactionInstructionLabeler.label(for: failedProgram)) · \(failedProgram)")
            }
            let filtered = filteredLogs(report)
            if filtered.isEmpty {
                Text("No logs match the current filter.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, line in
                DeveloperWorkstationScrollingMonospacedText(value: line)
            }
        }
    }

    private func transactionDebugAccounts(_ report: TransactionDebugReport) -> some View {
        GorkhPanel("Accounts") {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Account owner, lamports, and token details are intentionally absent until explicitly fetched.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Fetch is bounded to the first 20 transaction accounts and uses read-only account info.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
                Spacer()
                Button(isFetchingAccountDetails ? "Fetching..." : "Fetch Account Details") {
                    onFetchAccountDetails()
                }
                .buttonStyle(.bordered)
                .disabled(isFetchingAccountDetails || report.accountTable.isEmpty)
            }

            ForEach(report.accountTable) { account in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        WorkstationStatusChip(
                            title: account.isSigner ? "Signer" : "Non-signer",
                            systemImage: account.isSigner ? "signature" : "person",
                            color: account.isSigner ? GorkhColors.success : GorkhColors.secondaryText
                        )
                        WorkstationStatusChip(
                            title: account.isWritable ? "Writable" : "Readonly",
                            systemImage: account.isWritable ? "pencil" : "eye",
                            color: account.isWritable ? GorkhColors.warning : GorkhColors.success
                        )
                        Text("#\(account.index)")
                            .font(.caption.monospaced())
                    }
                    keyValue("Pubkey", account.pubkey)
                    keyValue("IDL account", account.idlAccountName ?? "Unmapped")
                    if account.detailFetchedAt != nil {
                        keyValue("Owner", account.ownerLabel.map { "\($0) · \(account.ownerProgram ?? "")" } ?? account.ownerProgram ?? "Unavailable")
                        keyValue("Lamports", account.lamports.map(String.init) ?? "Unavailable")
                        keyValue("Data length", account.dataLength.map(String.init) ?? "Unavailable")
                        if let mint = account.tokenMint {
                            keyValue("Token mint", mint)
                            keyValue("Token owner", account.tokenOwner ?? "Unavailable")
                            keyValue("Token amount", account.tokenAmountRaw ?? "Unavailable")
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func transactionDebugCompute(_ report: TransactionDebugReport) -> some View {
        GorkhPanel("Compute") {
            keyValue("Last consumed units", report.computeUnits.map(String.init) ?? "Unavailable")
            if report.computeTimeline.isEmpty {
                Text("No compute-unit log lines were present in the fetched transaction logs.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(report.computeTimeline) { event in
                VStack(alignment: .leading, spacing: 5) {
                    keyValue(event.programName, event.programID)
                    keyValue("Consumed", "\(event.consumed)")
                    keyValue("Limit", event.limit.map(String.init) ?? "Unavailable")
                    DeveloperWorkstationScrollingMonospacedText(value: event.line)
                }
                .padding(.vertical, 5)
            }
        }
    }

    private func transactionDebugErrorMapping(_ report: TransactionDebugReport) -> some View {
        GorkhPanel("Error Mapping") {
            if let anchorError = report.anchorError {
                keyValue("Anchor code", anchorError.errorCode ?? "Unavailable")
                keyValue("Anchor number", anchorError.errorNumber.map(String.init) ?? "Unavailable")
                keyValue("Anchor message", anchorError.errorMessage ?? "Unavailable")
                if let line = anchorError.sourceLine {
                    DeveloperWorkstationScrollingMonospacedText(value: line)
                }
            } else {
                Text("No Anchor error pattern was found in the logs.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            if let customError = report.customProgramError {
                keyValue("Custom error", "\(customError.hexCode) / \(customError.decimalCode)")
                keyValue("Program", customError.programID ?? "Unavailable")
                DeveloperWorkstationScrollingMonospacedText(value: customError.sourceLine)
            } else {
                keyValue("Custom program error", "Unavailable")
            }

            if let match = report.idlErrorMatch {
                WorkstationStatusChip(title: "IDL match", systemImage: "checkmark.circle", color: GorkhColors.success)
                keyValue(match.name, "\(match.code)")
                keyValue("Message", match.message ?? "No IDL message")
            } else {
                WorkstationStatusChip(title: "Unmapped", systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                Text("Load the matching Anchor IDL to map custom program errors when possible. The debugger does not invent error mappings.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func transactionDebugPDAChecks(_ report: TransactionDebugReport) -> some View {
        GorkhPanel("PDA / Account Checks") {
            if report.pdaMismatchCandidates.isEmpty {
                Text("No deterministic PDA/signature/writable mismatch was detected from the loaded IDL and Project Brain context.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(report.pdaMismatchCandidates) { finding in
                VStack(alignment: .leading, spacing: 5) {
                    WorkstationStatusChip(
                        title: finding.deterministic ? finding.severity.title : "Possible cause",
                        systemImage: finding.deterministic && finding.severity == .high ? "exclamationmark.triangle" : "info.circle",
                        color: finding.deterministic && finding.severity == .high ? GorkhColors.warning : GorkhColors.secondaryText
                    )
                    keyValue("Instruction", finding.instructionName ?? "Unavailable")
                    keyValue("Account", finding.accountName ?? "Unavailable")
                    keyValue("Expected", finding.expectedAddress ?? "Unavailable")
                    keyValue("Actual", finding.actualAddress ?? "Unavailable")
                    Text(finding.reason)
                        .font(.caption)
                        .foregroundStyle(finding.deterministic ? GorkhColors.warning : GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 5)
            }
        }
    }

    private func transactionDebugEvidenceView(_ report: TransactionDebugReport) -> some View {
        GorkhPanel("Evidence") {
            keyValue("Evidence id", report.evidenceId.uuidString)
            keyValue("Stored reports", "\(evidence.count)")
            keyValue("Stored payload", "Redacted summary only; raw transaction payload and RPC secrets are not stored.")
            keyValue("Logs stored", "\(report.logs.count) bounded line(s)")
            Button("Record Debug Review") {
                onRecordDebugReview()
            }
            .buttonStyle(.bordered)

            if !evidence.isEmpty {
                DisclosureGroup("Recent debug evidence") {
                    ForEach(evidence.prefix(8)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            keyValue(item.shortSignature, "\(item.cluster.title) · \(item.status.title)")
                            Text(item.likelyRootCause)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func filteredLogs(_ report: TransactionDebugReport) -> [String] {
        let filter = logFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filter.isEmpty else {
            return report.logs
        }
        return report.logs.filter { $0.localizedCaseInsensitiveContains(filter) }
    }

    private func statusColor(_ status: WorkstationDataStatus) -> Color {
        switch status {
        case .ready:
            return GorkhColors.success
        case .locked, .missing, .unavailable, .error:
            return GorkhColors.warning
        }
    }

    private func overviewCard(_ title: String, value: String, detail: String) -> some View {
        DeveloperWorkstationMetricCard(title: title, value: value, detail: detail)
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        DeveloperWorkstationKeyValueRow(key: key, value: value)
    }

    private func fallback(_ value: String, _ fallback: String) -> String {
        value.isEmpty ? fallback : value
    }
}
