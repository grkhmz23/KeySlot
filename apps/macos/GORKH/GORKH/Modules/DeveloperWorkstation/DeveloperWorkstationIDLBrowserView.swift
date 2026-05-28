import SwiftUI

struct DeveloperWorkstationIDLBrowserView: View {
    @Binding var idlText: String
    @Binding var idlFilter: String
    @Binding var idlDriftTargetPath: String
    let parsedIDL: WorkstationIDL?
    let currentProjectBrain: DeveloperProjectBrain?
    let idlDriftReport: WorkstationIDLDriftReport?
    let onParseIDL: () -> Void
    let onCompareIDLDrift: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("IDL Browser") {
                TextEditor(text: $idlText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(GorkhColors.border))
                Button("Parse IDL JSON", action: onParseIDL)
                    .buttonStyle(.borderedProminent)
                DeveloperWorkstationLabeledTextField(label: "Search IDL", text: $idlFilter, prompt: "instruction, account, type")
            }

            if let parsedIDL {
                GorkhPanel("IDL Summary") {
                    DeveloperWorkstationKeyValueRow(key: "Program", value: parsedIDL.name)
                    DeveloperWorkstationKeyValueRow(key: "Version", value: parsedIDL.version ?? "Unavailable")
                    DeveloperWorkstationKeyValueRow(key: "Summary", value: parsedIDL.summary)
                    DisclosureGroup("Instructions") {
                        ForEach(filteredInstructions(parsedIDL)) { instruction in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(instruction.name).fontWeight(.semibold)
                                Text("\(instruction.accounts.count) accounts, \(instruction.accounts.filter(\.isSigner).count) signers, \(instruction.accounts.filter(\.isMut).count) writable, \(instruction.args.count) args")
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    DisclosureGroup("Accounts") {
                        ForEach(filteredAccounts(parsedIDL)) { account in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.name).fontWeight(.semibold)
                                Text("Discriminator \(account.discriminatorHex)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(GorkhColors.secondaryText)
                                Text(account.fields.map { "\($0.name): \($0.type)" }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                        }
                    }
                    DisclosureGroup("Types / Events / Errors") {
                        Text("\(parsedIDL.types.count) types, \(parsedIDL.events.count) events, \(parsedIDL.errors.count) errors")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }

                GorkhPanel("Drift") {
                    Text("Compare the loaded IDL with a real project IDL file. On-chain IDL fetch is not enabled here; unavailable comparisons are shown honestly.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    if let brain = currentProjectBrain, !brain.idls.isEmpty {
                        Picker("Target project IDL", selection: $idlDriftTargetPath) {
                            Text("Choose IDL").tag("")
                            ForEach(brain.idls) { idl in
                                Text(idl.relativePath).tag(idl.relativePath)
                            }
                        }
                        .pickerStyle(.menu)
                        Button("Compare Loaded IDL", action: onCompareIDLDrift)
                            .buttonStyle(.bordered)
                            .disabled(idlDriftTargetPath.isEmpty)
                    } else {
                        Text("Scan Project Brain first to list local IDL files for drift comparison.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }
                    let staleFindings = WorkstationIDLDriftService.clientStalenessFindings(brain: currentProjectBrain)
                    if !staleFindings.isEmpty {
                        DisclosureGroup("Client staleness") {
                            ForEach(staleFindings) { finding in
                                DeveloperWorkstationDriftFindingRow(finding: finding)
                            }
                        }
                    }
                    if let idlDriftReport {
                        WorkstationStatusChip(
                            title: idlDriftReport.status.title,
                            systemImage: idlDriftReport.status == .ready ? "checkmark.circle" : "exclamationmark.triangle",
                            color: statusColor(idlDriftReport.status)
                        )
                        DeveloperWorkstationKeyValueRow(key: "Source", value: idlDriftReport.sourceName)
                        DeveloperWorkstationKeyValueRow(key: "Target", value: idlDriftReport.targetName)
                        Text(idlDriftReport.summary)
                            .font(.caption)
                            .foregroundStyle(idlDriftReport.status == .warning ? GorkhColors.warning : GorkhColors.secondaryText)
                        ForEach(idlDriftReport.findings) { finding in
                            DeveloperWorkstationDriftFindingRow(finding: finding)
                        }
                    }
                }
            }
        }
    }

    private func filteredInstructions(_ idl: WorkstationIDL) -> [WorkstationIDLInstruction] {
        let query = idlFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return idl.instructions
        }
        return idl.instructions.filter {
            $0.name.lowercased().contains(query) ||
                $0.args.contains { $0.name.lowercased().contains(query) || $0.type.lowercased().contains(query) } ||
                $0.accounts.contains { $0.name.lowercased().contains(query) }
        }
    }

    private func filteredAccounts(_ idl: WorkstationIDL) -> [WorkstationIDLAccount] {
        let query = idlFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return idl.accounts
        }
        return idl.accounts.filter {
            $0.name.lowercased().contains(query) ||
                $0.fields.contains { $0.name.lowercased().contains(query) || $0.type.lowercased().contains(query) }
        }
    }

    private func statusColor(_ status: WorkstationDataStatus) -> Color {
        switch status {
        case .ready:
            return GorkhColors.success
        case .locked, .missing, .unavailable, .error:
            return GorkhColors.warning
        }
    }

    private func statusColor(_ status: WorkstationV2ReportStatus) -> Color {
        switch status {
        case .ready:
            return GorkhColors.success
        case .warning, .blocked:
            return GorkhColors.warning
        case .unavailable:
            return GorkhColors.secondaryText
        }
    }
}

struct DeveloperWorkstationDriftFindingRow: View {
    let finding: WorkstationIDLDriftFinding

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                WorkstationStatusChip(
                    title: finding.severity.title,
                    systemImage: finding.severity == .high ? "exclamationmark.triangle" : "info.circle",
                    color: finding.severity == .info ? GorkhColors.success : GorkhColors.warning
                )
                Text(finding.category)
                    .fontWeight(.semibold)
            }
            DeveloperWorkstationKeyValueRow(key: "Source", value: finding.source)
            DeveloperWorkstationKeyValueRow(key: "Target", value: finding.target)
            Text(finding.detail)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(finding.suggestedAction)
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
    }
}
