import SwiftUI

struct DeveloperWorkstationTestWorkbenchView: View {
    let activeProject: WorkstationProject?
    let toolchainSnapshot: WorkstationToolchainSnapshot
    let localValidatorStatus: WorkstationLocalValidatorStatus
    let testDetection: TestFrameworkDetection
    @Binding var selectedTestFramework: WorkstationTestFrameworkKind
    let testCommandPreview: WorkstationCommandPlan?
    @Binding var testApprovalPhrase: String
    let testWorkbenchMessage: String
    let isDetectingTests: Bool
    let isRunningTests: Bool
    let testRunHistory: [TestRunEvidence]
    let currentProjectBrain: DeveloperProjectBrain?
    let computeMeasurementCount: Int
    let computeLatestStatus: String
    let securityScanReport: SecurityScanReport?
    let generatedTestDrafts: [WorkstationGeneratedTestDraft]
    let testDraftMessage: String
    let dateFormatter: DateFormatter
    let onRefreshDetection: () -> Void
    let onClearPreview: () -> Void
    let onPreparePreview: () -> Void
    let onRunApprovedTest: () -> Void
    let onCreateDraft: (WorkstationMissingTestSuggestion) -> Void

    var body: some View {
        let trusted = activeProject?.trustStatus == .trusted
        let selectedFramework = testDetection.frameworks.first { $0.kind == selectedTestFramework }
        let suggestions = TestWorkbenchService.suggestedMissingTests(from: currentProjectBrain)

        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("Test Workbench") {
                Text(TestWorkbenchService.executionRiskWarning)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
                    DeveloperWorkstationMetricCard(title: "Project", value: activeProject?.displayName ?? "No project", detail: activeProject?.localPath ?? "Import a project first.")
                    DeveloperWorkstationMetricCard(title: "Trust", value: activeProject?.trustStatus.title ?? "No project", detail: trusted ? "Commands can be prepared after approval." : "Test execution is blocked.")
                    DeveloperWorkstationMetricCard(title: "Toolchain", value: "\(toolchainSnapshot.availableCount)/\(WorkstationToolchainComponent.allCases.count) ready", detail: "Anchor/Cargo availability controls fixed commands.")
                    DeveloperWorkstationMetricCard(title: "Localnet", value: localValidatorStatus.state.title, detail: "Anchor test is pinned to localnet.")
                    DeveloperWorkstationMetricCard(title: "Last run", value: testRunHistory.first?.status.title ?? "None", detail: testRunHistory.first.map { dateFormatter.string(from: $0.completedAt) } ?? "No stored test evidence.")
                    DeveloperWorkstationMetricCard(title: "Compute", value: "\(computeMeasurementCount) measurements", detail: computeLatestStatus)
                }

                HStack {
                    Button(isDetectingTests ? "Detecting..." : "Refresh Detection", action: onRefreshDetection)
                        .buttonStyle(.borderedProminent)
                        .disabled(activeProject == nil || isDetectingTests)
                    Button("Clear Preview", action: onClearPreview)
                        .buttonStyle(.bordered)
                        .disabled(testCommandPreview == nil)
                }

                Text(testWorkbenchMessage)
                    .font(.caption)
                    .foregroundStyle(testWorkbenchMessage.lowercased().contains("failed") || testWorkbenchMessage.lowercased().contains("blocked") ? GorkhColors.warning : GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            detectedTestsPanel
            runFixedCommandPanel(selectedFramework: selectedFramework)
            runHistoryPanel
            suggestedTestsPanel(suggestions: suggestions)
        }
    }

    private var detectedTestsPanel: some View {
        GorkhPanel("Detected Tests") {
            if testDetection.frameworks.isEmpty {
                Text("No framework detection has been run for the selected project.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                ForEach(testDetection.frameworks) { framework in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            WorkstationStatusChip(
                                title: framework.support.title,
                                systemImage: framework.support == .supported ? "checkmark.circle" : "lock",
                                color: framework.support == .supported ? GorkhColors.success : GorkhColors.warning
                            )
                            Text(framework.kind.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GorkhColors.primaryText)
                            Spacer()
                            Button("Use") {
                                selectedTestFramework = framework.kind
                            }
                            .buttonStyle(.bordered)
                            .disabled(!framework.canPrepareCommand)
                        }
                        Text(framework.reason)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        if let command = framework.commandDescription {
                            Text(command)
                                .font(.caption.monospaced())
                                .foregroundStyle(GorkhColors.primaryText)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider().overlay(GorkhColors.border)
                }
            }

            if !testDetection.testFiles.isEmpty {
                Text("Test files")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GorkhColors.secondaryText)
                ForEach(testDetection.testFiles.prefix(12)) { file in
                    DeveloperWorkstationKeyValueRow(key: file.relativePath, value: file.kind)
                }
            }
        }
    }

    private func runFixedCommandPanel(selectedFramework: WorkstationDetectedTestFramework?) -> some View {
        GorkhPanel("Run Fixed Test Command") {
            Picker("Framework", selection: $selectedTestFramework) {
                ForEach(WorkstationTestFrameworkKind.allCases) { framework in
                    Text(framework.title).tag(framework)
                }
            }
            .pickerStyle(.menu)
            .disabled(isRunningTests)

            Text(selectedFramework?.reason ?? "Select a detected supported framework before preparing a command.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Prepare Preview", action: onPreparePreview)
                    .buttonStyle(.borderedProminent)
                    .disabled(activeProject == nil || isRunningTests)
                Button(isRunningTests ? "Running..." : "Run Approved Test", action: onRunApprovedTest)
                    .buttonStyle(.bordered)
                    .disabled(testCommandPreview == nil || testApprovalPhrase != TestWorkbenchService.approvalPhrase || isRunningTests)
            }

            if let preview = testCommandPreview {
                Text(TestWorkbenchService.executionRiskWarning)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GorkhColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
                DeveloperWorkstationKeyValueRow(key: "Project", value: activeProject?.displayName ?? "No project")
                DeveloperWorkstationKeyValueRow(key: "Project trust", value: activeProject?.trustStatus.title ?? "No project")
                DeveloperWorkstationKeyValueRow(key: "Working directory", value: preview.workingDirectory.map(WorkstationCommandRunner.safeSummary) ?? "Local process default")
                DeveloperWorkstationKeyValueRow(key: "Cluster assumption", value: preview.cluster?.title ?? "Local process only")
                DeveloperWorkstationKeyValueRow(key: "Evidence", value: "stdout/stderr are bounded and redacted before storage.")
                DeveloperWorkstationScrollingMonospacedText(value: preview.redactedPreview)
                DeveloperWorkstationKeyValueRow(key: "Writes to cluster", value: preview.writesToCluster ? "Yes" : "No")
                DeveloperWorkstationKeyValueRow(key: "Cluster", value: preview.cluster?.title ?? "Local process only")
            }

            DeveloperWorkstationLabeledTextField(label: "Approval phrase", text: $testApprovalPhrase, prompt: TestWorkbenchService.approvalPhrase)
            Text("No raw terminal input, package script picker, arbitrary flags, or mainnet write path exists here.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private var runHistoryPanel: some View {
        GorkhPanel("Run History") {
            if testRunHistory.isEmpty {
                Text("No test run evidence stored yet.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(testRunHistory.prefix(8)) { run in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        WorkstationStatusChip(
                            title: run.status.title,
                            systemImage: run.status == .succeeded ? "checkmark.circle" : "xmark.octagon",
                            color: run.status == .succeeded ? GorkhColors.success : GorkhColors.warning
                        )
                        Text(run.framework.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GorkhColors.primaryText)
                        Spacer()
                        Text(dateFormatter.string(from: run.completedAt))
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                    Text(run.commandSummary)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                    if run.status != .succeeded {
                        DeveloperWorkstationScrollingMonospacedText(value: [run.stdoutSummary, run.stderrSummary].filter { !$0.isEmpty }.joined(separator: "\n"))
                    }
                }
                .padding(.vertical, 6)
                Divider().overlay(GorkhColors.border)
            }
        }
    }

    private func suggestedTestsPanel(suggestions: [WorkstationMissingTestSuggestion]) -> some View {
        GorkhPanel("Suggested Missing Tests") {
            if suggestions.isEmpty {
                Text(currentProjectBrain == nil ? "Run Project Brain to generate deterministic missing-test suggestions." : "No deterministic missing-test suggestions found.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            ForEach(suggestions.prefix(16)) { suggestion in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        WorkstationStatusChip(
                            title: suggestion.severity.title,
                            systemImage: "testtube.2",
                            color: suggestion.severity == .high ? GorkhColors.warning : GorkhColors.secondaryText
                        )
                        Text(suggestion.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GorkhColors.primaryText)
                    }
                    Text(suggestion.detail)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    if let draft = suggestion.suggestedDraftName {
                        DeveloperWorkstationKeyValueRow(key: "Draft name", value: draft)
                    }
                    Button("Create Safe Draft") {
                        onCreateDraft(suggestion)
                    }
                    .buttonStyle(.bordered)
                    .disabled(activeProject == nil)
                }
                .padding(.vertical, 5)
            }

            securityLinkedTestIdeas

            Text(testDraftMessage)
                .font(.caption)
                .foregroundStyle(testDraftMessage.lowercased().contains("failed") ? GorkhColors.warning : GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            generatedDraftsPanel
        }
    }

    private var securityLinkedTestIdeas: some View {
        let scannerFindings = securityScanReport?.openFindings.filter { $0.severity == .high || $0.severity == .medium } ?? []
        return Group {
            if !scannerFindings.isEmpty {
                Divider().overlay(GorkhColors.border)
                Text("Security Scanner-linked test ideas")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GorkhColors.secondaryText)
                ForEach(scannerFindings.prefix(6)) { finding in
                    VStack(alignment: .leading, spacing: 4) {
                        WorkstationStatusChip(title: finding.severity.title, systemImage: "shield.lefthalf.filled", color: securitySeverityColor(finding.severity))
                        Text("Add a negative test for: \(finding.title)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GorkhColors.primaryText)
                        Text(finding.suggestedFix)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var generatedDraftsPanel: some View {
        Group {
            if !generatedTestDrafts.isEmpty {
                Divider().overlay(GorkhColors.border)
                Text("Generated drafts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GorkhColors.secondaryText)
                ForEach(generatedTestDrafts.prefix(8)) { draft in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            WorkstationStatusChip(title: draft.mode.title, systemImage: "doc.badge.plus", color: GorkhColors.success)
                            Text(draft.fileName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(GorkhColors.primaryText)
                        }
                        DeveloperWorkstationKeyValueRow(key: "Path", value: draft.safeRelativePath)
                        Text(draft.contentPreview)
                            .font(.caption.monospaced())
                            .foregroundStyle(GorkhColors.secondaryText)
                            .lineLimit(4)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private func securitySeverityColor(_ severity: SecurityFindingSeverity) -> Color {
        switch severity {
        case .info, .low:
            return GorkhColors.secondaryText
        case .medium, .high:
            return GorkhColors.warning
        }
    }
}
