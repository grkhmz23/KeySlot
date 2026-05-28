import SwiftUI

struct DeveloperWorkstationPDAExplorerView: View {
    let parsedIDL: WorkstationIDL?
    let activeProject: WorkstationProject?
    let programEvidence: [WorkstationProgramOperationEvidence]
    let currentProjectBrain: DeveloperProjectBrain?
    let manualPDAResult: WorkstationPDADerivationResult?
    let pdaAccountCheck: WorkstationPDAAccountCheck
    let isCheckingPDAAccount: Bool
    let idlDriftReport: WorkstationIDLDriftReport?
    @Binding var programID: String
    @Binding var accountAddress: String
    @Binding var pdaSeedInputs: [WorkstationPDASeedInput]
    @Binding var idlDriftTargetPath: String
    let onDeriveManualPDA: () -> Void
    let onCheckDerivedPDAAccount: () -> Void
    let onRecordPDAAnalysis: ([WorkstationPDAFinding]) -> Void
    let onRecordIDLDriftSummary: (WorkstationIDLDriftSummary) -> Void

    var body: some View {
        pdaExplorer
    }

    var pdaExplorer: some View {
        let findings = WorkstationPDAExplorerService.analyze(
            idl: parsedIDL,
            programID: programID.isEmpty ? nil : programID,
            expectedAddress: accountAddress.isEmpty ? nil : accountAddress
        )
        return VStack(alignment: .leading, spacing: 14) {
            manualPDASection
            pdaFindingsSection(findings)
        }
    }

    var idlDrift: some View {
        let drift = WorkstationIDLDriftService.summarize(
            idl: parsedIDL,
            selectedProgramID: programID.isEmpty ? nil : programID,
            evidence: programEvidence
        )
        return GorkhPanel("IDL Drift Detector") {
            Text("IDL Drift compares real parsed IDL metadata with public program ids from the input field and stored deploy evidence. Missing IDL address fields are reported honestly.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            DeveloperWorkstationLabeledTextField(label: "Selected program id", text: $programID, prompt: programEvidence.first?.programID ?? "Program public key")
            WorkstationStatusChip(
                title: drift.status.title,
                systemImage: drift.status == .ready ? "checkmark.circle" : "exclamationmark.triangle",
                color: statusColor(drift.status)
            )
            keyValue("IDL program", drift.idlProgramName ?? "Unavailable")
            keyValue("IDL address", drift.idlAddress ?? "Unavailable")
            keyValue("Selected", drift.selectedProgramID ?? "Unavailable")
            keyValue("Latest evidence", drift.latestEvidenceProgramID ?? "Unavailable")
            Text(drift.message)
                .font(.caption)
                .foregroundStyle(drift.status == .warning ? GorkhColors.warning : GorkhColors.secondaryText)
            Button("Record IDL Drift Review") {
                onRecordIDLDriftSummary(drift)
            }
            .buttonStyle(.bordered)
        }
    }

    var fixtureStudio: some View {
        GorkhPanel("Localnet Fixture & Snapshot Studio") {
            Text("Fixture Studio records what is actually available. It does not create fake accounts, fake snapshots, or fake deploy evidence.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            keyValue("Sample project", WorkstationSampleProject.anchorHelloWorld.path)
            keyValue("Active project", activeProject?.localPath ?? "Unavailable")
            keyValue("Localnet evidence", programEvidence.first(where: { $0.cluster == .localnet })?.programID ?? "Unavailable")
            keyValue("Snapshot source", "Unavailable pending policy review.")
            keyValue("Fixture write mode", "Locked to safe metadata review in this phase.")
            Text("Use Program Manager or the localnet smoke script for real localnet deploy evidence. Snapshot restore/export is intentionally unavailable pending policy review; no restore/export is claimed unless implemented.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
        }
    }

    private var manualPDASection: some View {
        GorkhPanel("Manual PDA Derivation") {
            Text("manual/concrete seeds derive real PDAs using Solana PDA hashing and ed25519 off-curve validation. dynamic instruction/account-derived seeds require runtime context and may be unavailable. No RPC write methods are available from this panel.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            DeveloperWorkstationLabeledTextField(label: "Program id", text: $programID, prompt: parsedIDL?.address ?? "Program public key")
            DeveloperWorkstationLabeledTextField(label: "Expected account address", text: $accountAddress, prompt: "Optional public account to compare")

            ForEach($pdaSeedInputs) { $seed in
                HStack(alignment: .top, spacing: 8) {
                    Picker("Seed type", selection: $seed.kind) {
                        ForEach(WorkstationPDASeedKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    TextField("Seed value", text: $seed.value)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        pdaSeedInputs.removeAll { $0.id == seed.id }
                        if pdaSeedInputs.isEmpty {
                            pdaSeedInputs.append(WorkstationPDASeedInput())
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(GorkhColors.warning)
                }
            }

            HStack {
                Button("Add Seed") {
                    pdaSeedInputs.append(WorkstationPDASeedInput())
                }
                Button("Derive PDA") {
                    onDeriveManualPDA()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                WorkstationStatusChip(
                    title: "Read-only",
                    systemImage: "eye",
                    color: GorkhColors.success
                )
            }
            .buttonStyle(.bordered)

            if let manualPDAResult {
                WorkstationStatusChip(
                    title: manualPDAResult.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                    systemImage: manualPDAResult.status == .derived ? "checkmark.circle" : "exclamationmark.triangle",
                    color: manualPDAResult.status == .derived ? GorkhColors.success : GorkhColors.warning
                )
                keyValue("Derived", manualPDAResult.derivedAddress ?? "Unavailable")
                keyValue("Bump", manualPDAResult.bump.map(String.init) ?? "Unavailable")
                keyValue("Seeds", fallback(manualPDAResult.seedSummary, "Unavailable"))
                Text(manualPDAResult.message)
                    .font(.caption)
                    .foregroundStyle(manualPDAResult.status == .derived ? GorkhColors.secondaryText : GorkhColors.warning)
                Button(isCheckingPDAAccount ? "Checking..." : "Check Account Existence") {
                    onCheckDerivedPDAAccount()
                }
                .buttonStyle(.bordered)
                .disabled(isCheckingPDAAccount || manualPDAResult.derivedAddress == nil)
            }

            WorkstationStatusChip(
                title: pdaAccountCheck.status.title,
                systemImage: pdaAccountCheck.status == .exists ? "checkmark.circle" : "info.circle",
                color: pdaAccountCheck.status == .exists ? GorkhColors.success : GorkhColors.secondaryText
            )
            keyValue("Owner", pdaAccountCheck.ownerLabel ?? pdaAccountCheck.ownerProgram ?? "Unavailable")
            keyValue("Lamports", pdaAccountCheck.lamports.map(String.init) ?? "Unavailable")
            keyValue("Data length", pdaAccountCheck.dataLength.map { "\($0) bytes" } ?? "Unavailable")
            keyValue("Decoded type", pdaAccountCheck.decodedAccountType ?? "Unavailable")
            Text(pdaAccountCheck.message)
                .font(.caption)
                .foregroundStyle(pdaAccountCheck.status == .unavailable ? GorkhColors.warning : GorkhColors.secondaryText)
        }
    }

    private func pdaFindingsSection(_ findings: [WorkstationPDAFinding]) -> some View {
        GorkhPanel("PDA Explorer") {
            Text("PDA Explorer uses Anchor IDL PDA metadata. It derives only when seeds are concrete and never guesses dynamic account or argument seed values.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            ForEach(findings) { finding in
                VStack(alignment: .leading, spacing: 6) {
                    WorkstationStatusChip(
                        title: finding.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                        systemImage: finding.status == .derived ? "checkmark.circle" : "exclamationmark.triangle",
                        color: finding.status == .derived ? GorkhColors.success : GorkhColors.warning
                    )
                    keyValue("Instruction", finding.instructionName)
                    keyValue("Account", finding.accountName)
                    keyValue("Seeds", finding.seedSummary)
                    keyValue("Derived", finding.derivedAddress ?? "Unavailable")
                    keyValue("Bump", finding.bump.map(String.init) ?? "Unavailable")
                    keyValue("Expected", finding.expectedAddress ?? "Unavailable")
                    Text(finding.message)
                        .font(.caption)
                        .foregroundStyle(finding.status == .mismatch ? GorkhColors.warning : GorkhColors.secondaryText)
                }
                .padding(.vertical, 6)
            }
            Button("Record PDA Analysis") {
                onRecordPDAAnalysis(findings)
            }
            .buttonStyle(.bordered)
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

    private func keyValue(_ key: String, _ value: String) -> some View {
        DeveloperWorkstationKeyValueRow(key: key, value: value)
    }

    private func fallback(_ value: String, _ fallback: String) -> String {
        value.isEmpty ? fallback : value
    }
}
