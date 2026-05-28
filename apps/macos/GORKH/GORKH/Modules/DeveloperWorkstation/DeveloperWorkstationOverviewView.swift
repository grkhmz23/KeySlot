import SwiftUI

struct DeveloperWorkstationOverviewView: View {
    let selectedCluster: WorkstationCluster
    let activeProject: WorkstationProject?
    let toolchainSnapshot: WorkstationToolchainSnapshot
    let developerWallet: DeveloperWalletMetadata
    let localValidatorStatus: WorkstationLocalValidatorStatus
    let programEvidence: [WorkstationProgramOperationEvidence]
    let currentProjectBrain: DeveloperProjectBrain?
    let projectBrainStatus: WorkstationDataStatus
    let projectBrainMessage: String
    let activity: [WorkstationActivityEvent]
    let evidenceStoreMessage: String
    let onSelectSection: (DeveloperWorkstationSection) -> Void
    let onCopyProgramID: (String) -> Void
    let onOpenIDLBrowser: () -> Void
    let onOpenLogs: (String?) -> Void
    let onPersistD8Evidence: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                DeveloperWorkstationMetricCard(title: "Cluster", value: selectedCluster.title, detail: selectedCluster.rpcURL.absoluteString)
                DeveloperWorkstationMetricCard(title: "Project", value: activeProject?.displayName ?? "No project", detail: activeProject?.trustStatus.title ?? "Import a project to begin.")
                DeveloperWorkstationMetricCard(title: "Toolchain", value: "\(toolchainSnapshot.availableCount)/\(WorkstationToolchainComponent.allCases.count) ready", detail: "Bundled, managed, then trusted system paths.")
                DeveloperWorkstationMetricCard(title: "Developer Wallet", value: developerWallet.status.title, detail: developerWallet.publicAddress.isEmpty ? "Separate localnet/devnet wallet only." : developerWallet.publicAddress)
                DeveloperWorkstationMetricCard(title: "Local Validator", value: localValidatorStatus.state.title, detail: localValidatorStatus.message)
                DeveloperWorkstationMetricCard(title: "Program Evidence", value: programEvidence.first?.status.title ?? "None", detail: programEvidence.first?.programID ?? "No stored program id.")
                DeveloperWorkstationMetricCard(title: "Project Brain", value: currentProjectBrain?.projectType.title ?? projectBrainStatus.title, detail: currentProjectBrain.map { "\($0.programs.count) programs, \($0.warnings.count) warnings" } ?? projectBrainMessage)
                DeveloperWorkstationMetricCard(title: "Activity", value: "\(activity.count) events", detail: "Redacted Workstation activity trail.")
            }

            GorkhPanel("Quick Actions") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    quickAction("Project Brain", systemImage: "brain.head.profile", target: .projectBrain)
                    quickAction("Debug Transaction", systemImage: "ladybug", target: .transactionDebugger)
                    quickAction("PDA Explorer", systemImage: "point.3.connected.trianglepath.dotted", target: .pdaExplorer)
                    quickAction("IDL Drift", systemImage: "arrow.triangle.2.circlepath", target: .idlDrift)
                    quickAction("Test Workbench", systemImage: "testtube.2", target: .testWorkbench)
                    quickAction("Compute Regression", systemImage: "chart.line.uptrend.xyaxis", target: .computeRegression)
                    quickAction("Import Project", systemImage: "folder.badge.plus", target: .projects)
                    quickAction("Check Compatibility", systemImage: "checklist.checked", target: .compatibility)
                    quickAction("Open IDL", systemImage: "curlybraces.square", target: .idlBrowser)
                    quickAction("Decode Account", systemImage: "doc.text.magnifyingglass", target: .accountDecoder)
                    quickAction("Security Scan", systemImage: "shield.lefthalf.filled", target: .securityScanner)
                    quickAction("Release Review", systemImage: "checkmark.seal", target: .releaseManager)
                    quickAction("View Logs", systemImage: "text.alignleft", target: .logs)
                    quickAction("RPC Playground", systemImage: "network", target: .rpcPlayground)
                    quickAction("Airdrop Dev SOL", systemImage: "drop", target: .localnet)
                    quickAction("Build / Deploy", systemImage: "hammer", target: .programManager)
                    quickAction("Workstation Agent", systemImage: "sparkles", target: .workstationAgent)
                    quickAction("Offline Signing", systemImage: "externaldrive.badge.lock", target: .offlineSigning)
                }
            }

            DeveloperWorkstationCapabilityStatusPanel(
                capabilities: DeveloperWorkstationCapabilityCatalog.capabilities,
                manualQAItems: DeveloperWorkstationCapabilityCatalog.manualQAItems,
                onOpenSection: onSelectSection
            )

            DeveloperWorkstationProgramEvidencePanel(
                evidenceStoreMessage: evidenceStoreMessage,
                programEvidence: programEvidence,
                onCopyProgramID: onCopyProgramID,
                onOpenIDLBrowser: onOpenIDLBrowser,
                onOpenLogs: onOpenLogs,
                onPersistD8Evidence: onPersistD8Evidence
            )
        }
    }

    private func quickAction(_ title: String, systemImage: String, target: DeveloperWorkstationSection) -> some View {
        Button {
            onSelectSection(target)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }
}

struct DeveloperWorkstationProgramEvidencePanel: View {
    let evidenceStoreMessage: String
    let programEvidence: [WorkstationProgramOperationEvidence]
    let onCopyProgramID: (String) -> Void
    let onOpenIDLBrowser: () -> Void
    let onOpenLogs: (String?) -> Void
    let onPersistD8Evidence: () -> Void

    var body: some View {
        GorkhPanel("Program Operation Evidence") {
            Text(evidenceStoreMessage)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)

            if let latest = programEvidence.first {
                WorkstationStatusChip(
                    title: "\(latest.cluster.title) \(latest.status.title)",
                    systemImage: latest.status == .succeeded ? "checkmark.seal" : "exclamationmark.triangle",
                    color: latest.status == .succeeded ? GorkhColors.success : GorkhColors.warning
                )
                DeveloperWorkstationKeyValueRow(key: "Operation", value: latest.operation.title)
                DeveloperWorkstationKeyValueRow(key: "Project", value: latest.projectName)
                DeveloperWorkstationKeyValueRow(key: "Program id", value: latest.programID ?? "Unavailable")
                DeveloperWorkstationKeyValueRow(key: "Signature", value: latest.signature ?? "Unavailable")
                DeveloperWorkstationKeyValueRow(key: "Temp key cleanup", value: latest.tempKeyCleanupStatus.title)
                DeveloperWorkstationKeyValueRow(key: "Command", value: latest.commandSummary)
                DeveloperWorkstationKeyValueRow(key: "IDL", value: latest.idlPath ?? "Unavailable")
                DeveloperWorkstationKeyValueRow(key: "Artifact", value: latest.artifactPath ?? "Unavailable")
                DisclosureGroup("Tool versions") {
                    ForEach(latest.toolVersions.keys.sorted(), id: \.self) { key in
                        DeveloperWorkstationKeyValueRow(key: key, value: latest.toolVersions[key] ?? "")
                    }
                }
                DisclosureGroup("Log summary") {
                    Text(latest.logSummary)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    Button("Copy Program ID") {
                        if let programID = latest.programID {
                            onCopyProgramID(programID)
                        }
                    }
                    .disabled(latest.programID == nil)
                    Button("Open IDL Browser", action: onOpenIDLBrowser)
                    Button("Open Logs") {
                        onOpenLogs(latest.programID)
                    }
                    Button("Persist D8 Evidence", action: onPersistD8Evidence)
                }
                .buttonStyle(.bordered)
            } else {
                Text("No safe program-operation evidence has been stored yet.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }
}
