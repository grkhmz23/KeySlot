import SwiftUI

struct TransactionInstructionTimelineView: View {
    let decoded: DecodedTransaction?
    let addressSummary: TransactionStudioAddressSummary?
    let accountEnrichment: TransactionAccountEnrichmentReport

    var body: some View {
        GorkhPanel("Decode Timeline") {
            if let addressSummary {
                addressView(addressSummary)
            } else if let decoded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        metadata(decoded)
                        altPanel(decoded)
                        accountEnrichmentPanel(accountEnrichment)
                        ForEach(decoded.instructions) { instruction in
                            instructionRow(instruction)
                        }
                    }
                }
                .frame(maxHeight: 540)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing decoded yet.")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
            Text("Paste a Solana signature, raw transaction, or address. Unknown instructions are shown honestly without fake decoding.")
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private func metadata(_ decoded: DecodedTransaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                GorkhStatusChip(title: decoded.transactionVersion, systemImage: "doc.text", color: GorkhColors.accent)
                GorkhStatusChip(title: "\(decoded.instructions.count) instruction(s)", systemImage: "list.bullet", color: GorkhColors.accent)
                GorkhStatusChip(title: "\(decoded.staticAccountCount) static account(s)", systemImage: "person.2", color: GorkhColors.accent)
                if decoded.addressLookupTables.isEmpty == false {
                    GorkhStatusChip(title: "\(decoded.addressLookupTables.count) ALT", systemImage: "tablecells", color: GorkhColors.warning)
                }
            }
            Text("Fee payer: \(decoded.feePayer ?? "unknown")")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
            Text("Recent blockhash: \(decoded.recentBlockhash)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
        }
    }

    private func altPanel(_ decoded: DecodedTransaction) -> some View {
        DisclosureGroup {
            if decoded.addressLookupTables.isEmpty {
                Text("No address lookup tables are referenced.")
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        GorkhStatusChip(title: "\(decoded.addressLookupOverview.loadedWritableCount) loaded writable", systemImage: "square.and.pencil", color: GorkhColors.warning)
                        GorkhStatusChip(title: "\(decoded.addressLookupOverview.loadedReadonlyCount) loaded readonly", systemImage: "eye", color: GorkhColors.accent)
                        if decoded.addressLookupOverview.unresolvedTableCount > 0 {
                            GorkhStatusChip(title: "\(decoded.addressLookupOverview.unresolvedTableCount) unresolved", systemImage: "questionmark.diamond", color: GorkhColors.warning)
                        }
                    }
                    ForEach(decoded.addressLookupTables) { table in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(table.tableAddress)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(GorkhColors.primaryText)
                                .textSelection(.enabled)
                            Text("Writable indexes: \(table.writableIndexes.map(String.init).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            Text("Readonly indexes: \(table.readonlyIndexes.map(String.init).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            Text("Status: \(table.resolutionStatus.title)\(table.resolutionReason.map { " - \($0)" } ?? "")")
                                .font(.caption)
                                .foregroundStyle(table.resolutionStatus == .loaded ? GorkhColors.secondaryText : GorkhColors.warning)
                            ForEach(table.loadedWritableAddresses.prefix(6), id: \.self) { address in
                                Text("Writable: \(address)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(GorkhColors.warning)
                                    .textSelection(.enabled)
                            }
                            ForEach(table.loadedReadonlyAddresses.prefix(6), id: \.self) { address in
                                Text("Readonly: \(address)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(GorkhColors.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(8)
                        .background(GorkhColors.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        } label: {
            Text("Versioned transaction / ALT review")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
        }
    }

    private func accountEnrichmentPanel(_ report: TransactionAccountEnrichmentReport) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    GorkhStatusChip(title: report.status.title, systemImage: "magnifyingglass", color: report.status == .loaded ? GorkhColors.success : GorkhColors.warning)
                    Text("Requested \(report.requestedCount)/\(report.maxRequestedCount) bounded account(s)")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
                if report.truncated {
                    Text("Watchlist was truncated to avoid heavy RPC usage.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
                if let reason = report.unavailableReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
                ForEach(report.accounts.prefix(12)) { account in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(account.address)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(GorkhColors.primaryText)
                            .textSelection(.enabled)
                        Text("Owner: \(account.ownerLabel ?? account.ownerProgram ?? "unknown") | Lamports: \(account.lamports.map(String.init) ?? "unknown") | Data: \(account.dataLength.map(String.init) ?? "unknown") bytes")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        if let mint = account.tokenMint {
                            Text("Token account: mint \(mint), amount \(account.tokenUIAmount ?? account.tokenAmountRaw ?? "unknown")")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                    .padding(8)
                    .background(GorkhColors.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        } label: {
            Text("Bounded account enrichment")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
        }
    }

    private func instructionRow(_ instruction: DecodedInstruction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(instruction.index)")
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
                GorkhStatusChip(title: instruction.programLabel, systemImage: "cpu", color: instruction.programLabel == "Unknown Program" ? GorkhColors.warning : GorkhColors.accent)
                GorkhStatusChip(title: instruction.parseStatus.title, systemImage: instruction.parseStatus == .recognized ? "checkmark.seal" : "questionmark.diamond", color: instruction.parseStatus == .recognized ? GorkhColors.success : GorkhColors.warning)
                Spacer()
                Text("\(instruction.accounts.count) account(s), \(instruction.dataLength) byte(s)")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            Text(instruction.decodedAction)
                .foregroundStyle(GorkhColors.primaryText)
            Text(instruction.programID)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
            if instruction.parsedSummary.details.isEmpty == false {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(instruction.parsedSummary.details.prefix(6)) { detail in
                        HStack(alignment: .top) {
                            Text(detail.label)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                                .frame(width: 132, alignment: .leading)
                            Text(detail.value)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(GorkhColors.primaryText)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(8)
                .background(GorkhColors.panel)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            if instruction.riskHints.isEmpty == false {
                HStack {
                    ForEach(instruction.riskHints, id: \.self) { hint in
                        GorkhStatusChip(title: hint, systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                    }
                }
            }
        }
        .padding(12)
        .background(GorkhColors.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func addressView(_ summary: TransactionStudioAddressSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.address)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            HStack {
                GorkhStatusChip(title: summary.ownerLabel ?? "Unknown owner", systemImage: "person.crop.square", color: GorkhColors.accent)
                if summary.executable == true {
                    GorkhStatusChip(title: "Executable", systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                }
            }
            Text("Lamports: \(summary.lamports.map(String.init) ?? "unknown")")
                .foregroundStyle(GorkhColors.secondaryText)
            Text("Data length: \(summary.dataLength.map(String.init) ?? "unknown")")
                .foregroundStyle(GorkhColors.secondaryText)
            if let tokenAccountSummary = summary.tokenAccountSummary {
                Text(tokenAccountSummary)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            if let warning = summary.warning {
                Text(warning)
                    .foregroundStyle(GorkhColors.warning)
            }
        }
    }
}
