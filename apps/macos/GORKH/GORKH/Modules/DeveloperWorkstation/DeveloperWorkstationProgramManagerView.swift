import SwiftUI

struct DeveloperWorkstationProgramManagerView: View {
    let selectedCluster: WorkstationCluster
    let activeProject: WorkstationProject?
    let toolchainSnapshot: WorkstationToolchainSnapshot
    let developerWallet: DeveloperWalletMetadata
    @Binding var selectedTab: WorkstationProgramManagerTab
    @Binding var operation: WorkstationProgramOperation
    @Binding var programID: String
    @Binding var artifactPath: String
    @Binding var newAuthority: String
    @Binding var destructivePhrase: String
    @Binding var devnetCertificationPhrase: String
    let programCommandPreview: String
    let programEvidence: [WorkstationProgramOperationEvidence]
    let localnetSmokePreflight: WorkstationLocalnetSmokePreflight?
    let releaseStoreMessage: String
    let releaseRecords: [WorkstationDeploymentReleaseRecord]
    let deploymentPreflightReport: WorkstationDeploymentPreflightReport
    let dateFormatter: DateFormatter
    let onPrepareCommandPreview: () -> Void
    let onRunPreflight: () -> Void
    let onCreateReleaseRecord: () -> Void
    let onPrepareLocalnetSmokePreflight: () -> Void
    let onCopyLatestReleaseJSON: () -> Void
    let onCopyProgramID: (String) -> Void
    let onCopySignature: (String) -> Void
    let onOpenIDLDrift: () -> Void
    let onOpenLogs: (String?) -> Void

    var body: some View {
        let decision = WorkstationProgramManager.evaluate(
            WorkstationProgramOperationRequest(
                operation: operation,
                cluster: selectedCluster,
                project: activeProject,
                toolchain: toolchainSnapshot,
                developerWallet: developerWallet,
                artifactPath: artifactPath.isEmpty ? nil : artifactPath,
                programID: programID.isEmpty ? nil : programID,
                newAuthority: newAuthority.isEmpty ? nil : newAuthority,
                exactPhrase: destructivePhrase
            )
        )

        let devnetDecision = WorkstationDevnetCertificationPolicy.validate(
            cluster: selectedCluster,
            project: activeProject,
            toolchain: toolchainSnapshot,
            developerWallet: developerWallet,
            confirmation: devnetCertificationPhrase
        )

        return VStack(alignment: .leading, spacing: 14) {
            headerPanel

            switch selectedTab {
            case .buildDeploy:
                buildDeployPanel(decision: decision)
            case .upgradePreview:
                upgradePreviewPanel
            case .authorityPreview:
                authorityPreviewPanel
            case .releaseRecords:
                releaseRecordsPanel
            case .preflightChecks:
                deploymentPreflightPanel
            }

            devnetCertificationPanel(devnetDecision)
        }
    }

    private var headerPanel: some View {
        GorkhPanel("Deployment Release Manager") {
            Text("Localnet/devnet program ops are gated by project trust, fixed command builders, a separate developer wallet, and explicit approval. Mainnet operations are locked.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)

            Picker("Release manager section", selection: $selectedTab) {
                ForEach(WorkstationProgramManagerTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func buildDeployPanel(decision: WorkstationProgramOperationDecision) -> some View {
        GorkhPanel("Build / Deploy") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Operation", selection: $operation) {
                    ForEach(WorkstationProgramOperation.allCases) { operation in
                        Text(operation.title).tag(operation)
                    }
                }
                .pickerStyle(.menu)

                DeveloperWorkstationLabeledTextField(label: "Program id", text: $programID, prompt: "Program public key")
                DeveloperWorkstationLabeledTextField(label: "Artifact path", text: $artifactPath, prompt: "target/deploy/program.so")
                if operation == .solanaTransferUpgradeAuthority {
                    DeveloperWorkstationLabeledTextField(label: "New upgrade authority", text: $newAuthority, prompt: "New authority public key")
                }
                if let requiredPhrase = WorkstationProgramManager.requiredPhrase(for: operation) {
                    Text(requiredPhrase)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.warning)
                        .textSelection(.enabled)
                    DeveloperWorkstationLabeledTextField(label: "Exact approval phrase", text: $destructivePhrase, prompt: requiredPhrase)
                } else {
                    Text("This operation still requires explicit approval after preview; no destructive phrase is needed.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                WorkstationStatusChip(
                    title: decision.isAllowed ? "Ready for explicit approval" : "Blocked",
                    systemImage: decision.isAllowed ? "checkmark.shield" : "lock.shield",
                    color: decision.isAllowed ? GorkhColors.success : GorkhColors.warning
                )
                ForEach(decision.reasons, id: \.self) { reason in
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(decision.isAllowed ? GorkhColors.success : GorkhColors.warning)
                }

                Button("Prepare Fixed Command Preview", action: onPrepareCommandPreview)
                    .buttonStyle(.borderedProminent)
                    .disabled(!decision.isAllowed)

                DeveloperWorkstationScrollingMonospacedText(value: programCommandPreview)

                Text("Command preview is generated only from fixed builders. No raw terminal input or arbitrary flags are accepted.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                Divider().overlay(GorkhColors.border)

                HStack {
                    Button("Run Preflight Checks", action: onRunPreflight)
                        .buttonStyle(.bordered)
                    Button("Create Release Record From Latest Evidence", action: onCreateReleaseRecord)
                        .buttonStyle(.borderedProminent)
                        .disabled(programEvidence.isEmpty)
                }
                WorkstationStatusChip(
                    title: deploymentPreflightReport.status.title,
                    systemImage: deploymentPreflightReport.isDeployReady ? "checkmark.circle" : "exclamationmark.triangle",
                    color: deploymentPreflightReport.isDeployReady ? GorkhColors.success : GorkhColors.warning
                )
                Text(deploymentPreflightReport.summary)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                Divider().overlay(GorkhColors.border)

                Text("Sample Localnet Smoke")
                    .font(.headline)
                Button("Run Sample Localnet Smoke Preflight", action: onPrepareLocalnetSmokePreflight)
                    .buttonStyle(.bordered)
                if let localnetSmokePreflight {
                    WorkstationStatusChip(
                        title: localnetSmokePreflight.status.title,
                        systemImage: localnetSmokePreflight.status == .ready ? "checkmark.circle" : "lock",
                        color: localnetSmokePreflight.status == .ready ? GorkhColors.success : GorkhColors.warning
                    )
                    Text(localnetSmokePreflight.summary)
                        .font(.caption)
                        .foregroundStyle(localnetSmokePreflight.status == .ready ? GorkhColors.success : GorkhColors.warning)
                    DisclosureGroup("Fixed smoke steps") {
                        ForEach(localnetSmokePreflight.steps, id: \.self) { step in
                            Text(step)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private var upgradePreviewPanel: some View {
        GorkhPanel("Upgrade Preview") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upgrade previews use the existing Program Manager policy. Localnet/devnet only; exact phrase required; no automatic execution.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Button("Use Upgrade Operation") {
                    operation = .solanaProgramUpgrade
                    destructivePhrase = ""
                }
                .buttonStyle(.bordered)
                DeveloperWorkstationLabeledTextField(label: "Program id", text: $programID, prompt: "Program public key")
                DeveloperWorkstationLabeledTextField(label: "Artifact path", text: $artifactPath, prompt: "target/deploy/program.so")
                Text(WorkstationProgramManager.upgradePhrase)
                    .font(.caption.monospaced())
                    .foregroundStyle(GorkhColors.warning)
                    .textSelection(.enabled)
                DeveloperWorkstationLabeledTextField(label: "Exact approval phrase", text: $destructivePhrase, prompt: WorkstationProgramManager.upgradePhrase)
                Button("Prepare Upgrade Preview") {
                    operation = .solanaProgramUpgrade
                    onPrepareCommandPreview()
                }
                .buttonStyle(.borderedProminent)
                DeveloperWorkstationScrollingMonospacedText(value: programCommandPreview)
            }
        }
    }

    private var authorityPreviewPanel: some View {
        GorkhPanel("Authority Preview") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Authority transfer and revoke are previewed through fixed Solana CLI builders, localnet/devnet only. Mainnet remains locked.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                DeveloperWorkstationLabeledTextField(label: "Program id", text: $programID, prompt: "Program public key")
                DeveloperWorkstationLabeledTextField(label: "New upgrade authority", text: $newAuthority, prompt: "Required for transfer only")
                HStack {
                    Button("Preview Transfer Authority") {
                        operation = .solanaTransferUpgradeAuthority
                        destructivePhrase = WorkstationProgramManager.transferAuthorityPhrase
                        onPrepareCommandPreview()
                    }
                    .buttonStyle(.bordered)
                    Button("Preview Revoke Authority") {
                        operation = .solanaRevokeUpgradeAuthority
                        destructivePhrase = WorkstationProgramManager.revokeAuthorityPhrase
                        onPrepareCommandPreview()
                    }
                    .buttonStyle(.bordered)
                }
                Text("Required phrases")
                    .font(.caption.bold())
                    .foregroundStyle(GorkhColors.primaryText)
                Text(WorkstationProgramManager.transferAuthorityPhrase)
                    .font(.caption.monospaced())
                    .foregroundStyle(GorkhColors.warning)
                    .textSelection(.enabled)
                Text(WorkstationProgramManager.revokeAuthorityPhrase)
                    .font(.caption.monospaced())
                    .foregroundStyle(GorkhColors.warning)
                    .textSelection(.enabled)
                DeveloperWorkstationScrollingMonospacedText(value: programCommandPreview)
            }
        }
    }

    private var releaseRecordsPanel: some View {
        GorkhPanel("Release Records") {
            VStack(alignment: .leading, spacing: 12) {
                Text(releaseStoreMessage)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                HStack {
                    Button("Create From Latest Evidence", action: onCreateReleaseRecord)
                        .buttonStyle(.borderedProminent)
                        .disabled(programEvidence.isEmpty)
                    Button("Copy Latest Redacted JSON", action: onCopyLatestReleaseJSON)
                        .buttonStyle(.bordered)
                        .disabled(releaseRecords.isEmpty)
                }
                if releaseRecords.isEmpty {
                    Text("No release records stored yet. A record is created from real deploy/upgrade evidence and local artifact/IDL hashes.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ForEach(releaseRecords.prefix(12)) { record in
                        releaseRecordCard(record)
                    }
                }
            }
        }
    }

    private func releaseRecordCard(_ record: WorkstationDeploymentReleaseRecord) -> some View {
        let chipTitle = record.status.title
        let chipImage = record.status == .succeeded ? "checkmark.seal" : "exclamationmark.triangle"
        let chipColor = record.status == .succeeded ? GorkhColors.success : GorkhColors.warning
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                WorkstationStatusChip(title: chipTitle, systemImage: chipImage, color: chipColor)
                Text(record.projectName)
                    .font(.headline)
                Spacer()
                Text(dateFormatter.string(from: record.createdAt))
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            DeveloperWorkstationKeyValueRow(key: "Cluster", value: record.cluster.title)
            DeveloperWorkstationKeyValueRow(key: "Operation", value: record.operation.title)
            DeveloperWorkstationKeyValueRow(key: "Program id", value: record.programId ?? "Unavailable")
            DeveloperWorkstationKeyValueRow(key: "Signature", value: record.signature ?? "Unavailable")
            DeveloperWorkstationKeyValueRow(key: "Artifact hash", value: record.artifactHash ?? "Unavailable")
            DeveloperWorkstationKeyValueRow(key: "IDL hash", value: record.idlHash ?? "Unavailable")
            DeveloperWorkstationKeyValueRow(key: "Git", value: "\(record.gitCommit ?? "Unavailable") · \(record.gitDirtyStatus)")
            releaseRecordActionRow(record)
            DisclosureGroup("Tool versions and command") {
                ForEach(record.toolVersions.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    DeveloperWorkstationKeyValueRow(key: key, value: value)
                }
                DeveloperWorkstationScrollingMonospacedText(value: record.commandSummary)
                if let failure = record.failureSummary {
                    DeveloperWorkstationScrollingMonospacedText(value: failure)
                }
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func releaseRecordActionRow(_ record: WorkstationDeploymentReleaseRecord) -> some View {
        HStack {
            Button("Copy Program Id") {
                if let programId = record.programId {
                    onCopyProgramID(programId)
                }
            }
            .buttonStyle(.bordered)
            .disabled(record.programId == nil)
            Button("Copy Signature") {
                if let signature = record.signature {
                    onCopySignature(signature)
                }
            }
            .buttonStyle(.bordered)
            .disabled(record.signature == nil)
            Button("Open IDL Drift", action: onOpenIDLDrift)
                .buttonStyle(.bordered)
            Button("Open Logs") {
                onOpenLogs(record.programId)
            }
            .buttonStyle(.bordered)
        }
    }

    private var deploymentPreflightPanel: some View {
        GorkhPanel("Preflight Checks") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    WorkstationStatusChip(
                        title: deploymentPreflightReport.status.title,
                        systemImage: deploymentPreflightReport.isDeployReady ? "checkmark.shield" : "lock.shield",
                        color: deploymentPreflightReport.isDeployReady ? GorkhColors.success : GorkhColors.warning
                    )
                    Text(deploymentPreflightReport.summary)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Spacer()
                    Button("Run Preflight", action: onRunPreflight)
                        .buttonStyle(.borderedProminent)
                }
                Text("Preflight checks are local/read-only except optional balance tooling handled elsewhere. They do not deploy or sign.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                ForEach(deploymentPreflightReport.checks) { check in
                    HStack(alignment: .top, spacing: 10) {
                        WorkstationStatusChip(
                            title: check.status.title,
                            systemImage: check.status == .passed ? "checkmark.circle" : "exclamationmark.triangle",
                            color: check.status == .passed ? GorkhColors.success : GorkhColors.warning
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(check.title)
                                .font(.caption.bold())
                                .foregroundStyle(GorkhColors.primaryText)
                            Text(check.detail)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func devnetCertificationPanel(_ decision: WorkstationProgramOperationDecision) -> some View {
        GorkhPanel("Devnet Certification") {
            Text("Devnet certification is manual/gated and depends on funding, RPC reliability, and explicit approval. KeySlot requires a trusted project, Developer Workstation wallet, active toolchain, Devnet selection, fixed command preview, and exact confirmation.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(WorkstationDevnetCertificationPolicy.requiredConfirmation)
                .font(.caption.monospaced())
                .foregroundStyle(GorkhColors.warning)
                .textSelection(.enabled)
            DeveloperWorkstationLabeledTextField(label: "Devnet confirmation", text: $devnetCertificationPhrase, prompt: WorkstationDevnetCertificationPolicy.requiredConfirmation)
            WorkstationStatusChip(
                title: decision.isAllowed ? "Devnet certification ready" : "Devnet certification blocked",
                systemImage: decision.isAllowed ? "checkmark.shield" : "lock.shield",
                color: decision.isAllowed ? GorkhColors.success : GorkhColors.warning
            )
            ForEach(decision.reasons, id: \.self) { reason in
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(decision.isAllowed ? GorkhColors.success : GorkhColors.warning)
            }
            Text("Use `scripts/workstation-program-ops-smoke.sh --devnet-sample --confirm-devnet` for the CLI smoke path. It skips safely if the dev wallet is not funded or prerequisites are missing.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }
}
