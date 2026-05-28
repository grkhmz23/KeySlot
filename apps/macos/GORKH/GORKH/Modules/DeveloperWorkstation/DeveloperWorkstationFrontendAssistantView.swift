import SwiftUI

struct DeveloperWorkstationFrontendAssistantView: View {
    let activeProject: WorkstationProject?
    let currentProjectBrain: DeveloperProjectBrain?
    let parsedIDL: WorkstationIDL?
    let frontendReport: FrontendAssistantReport?
    let frontendDrafts: [FrontendGeneratedFileDraft]
    let frontendEvidence: [FrontendGenerationEvidence]
    let frontendMessage: String
    @Binding var selectedInstruction: String
    @Binding var draftKind: FrontendGeneratedFileKind
    @Binding var writeApprovalPhrase: String
    let onInspectFrontend: () -> Void
    let onCopyDraftPreview: () -> Void
    let onPrepareDrafts: () -> Void
    let onWriteDrafts: () -> Void
    let onRevealGeneratedFile: (String) -> Void

    var body: some View {
        let report = WorkstationFrontendIntegrationService.report(project: activeProject, projectBrain: currentProjectBrain, idl: parsedIDL)
        VStack(alignment: .leading, spacing: 14) {
            reportPanel(report)
            integrationBoundary
            detectedFrontend
            draftGenerator
            generatedDraftPreview
            frontendEvidencePanel
        }
    }

    private var integrationBoundary: some View {
        GorkhPanel("Integration Boundary") {
            Text("Frontend Assistant inspects real frontend files and loaded IDL metadata. It never installs packages, runs scripts, signs, sends, or broadcasts.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                statusChip("Native SwiftUI", color: GorkhColors.success)
                statusChip("Preview first", color: GorkhColors.warning)
                statusChip("No package install", color: GorkhColors.success)
                statusChip("No overwrite by default", color: GorkhColors.success)
            }
            keyValue("Project", activeProject?.displayName ?? "Unavailable")
            keyValue("IDL", parsedIDL?.name ?? "Unavailable")
            keyValue("Instruction count", parsedIDL.map { "\($0.instructions.count)" } ?? "Unavailable")
            keyValue("Account count", parsedIDL.map { "\($0.accounts.count)" } ?? "Unavailable")
            HStack {
                Button("Inspect Frontend") {
                    onInspectFrontend()
                }
                .buttonStyle(.borderedProminent)

                Button("Copy Draft Preview") {
                    onCopyDraftPreview()
                }
                .buttonStyle(.bordered)
                .disabled(frontendDrafts.isEmpty)
            }
            Text(frontendMessage)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var detectedFrontend: some View {
        if let frontendReport {
            GorkhPanel("Detected Frontend") {
                keyValue("Status", frontendReport.status.title)
                keyValue("Scanned files", "\(frontendReport.scannedFileCount)")
                keyValue("Dependency style", frontendReport.recommendedDependencyStyle)
                keyValue("package.json", fallback(frontendReport.detectedSurface.packageJSONPaths.joined(separator: ", "), "Not detected"))
                keyValue("Framework hints", fallback(frontendReport.detectedSurface.frameworkHints.joined(separator: ", "), "Not detected"))
                keyValue("Generated clients", fallback(frontendReport.detectedSurface.generatedClients.joined(separator: ", "), "Not detected"))
                keyValue("IDL imports", fallback(frontendReport.detectedSurface.idlImports.joined(separator: ", "), "Not detected"))
                keyValue("Cluster hints", fallback(frontendReport.detectedSurface.clusterHints.joined(separator: ", "), "Not detected"))
                keyValue("Hardcoded program IDs", fallback(frontendReport.detectedSurface.hardcodedProgramIDs.prefix(4).joined(separator: ", "), "Not detected"))
            }

            GorkhPanel("Frontend Warnings") {
                if frontendReport.findings.isEmpty {
                    statusChip("No frontend warnings in bounded scan", color: GorkhColors.success)
                } else {
                    ForEach(frontendReport.findings) { finding in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                statusChip(finding.severity.title, color: frontendSeverityColor(finding.severity))
                                Text(finding.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                            Text(finding.detail)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            keyValue("Source", fallback([finding.sourceRelativePath, finding.line.map { "line \($0)" }].compactMap { $0 }.joined(separator: " · "), "Project metadata"))
                            keyValue("Evidence", finding.evidence)
                            keyValue("Suggested action", finding.suggestedAction)
                        }
                        .padding(10)
                        .background(GorkhColors.panelElevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        } else {
            GorkhPanel("No Frontend Scan") {
                Text("Press Inspect Frontend to scan package.json and bounded TypeScript/React client paths. Untrusted projects are allowed because this only reads files.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var draftGenerator: some View {
        GorkhPanel("Draft Generator") {
            Text("Generated files are drafts. They separate build/send concerns and never include wallet secrets or automatic broadcast behavior.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Draft", selection: $draftKind) {
                ForEach(FrontendGeneratedFileKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)

            Picker("Instruction", selection: $selectedInstruction) {
                Text("Select instruction").tag("")
                ForEach(parsedIDL?.instructions ?? []) { instruction in
                    Text(instruction.name).tag(instruction.name)
                }
            }
            .pickerStyle(.menu)
            .disabled(parsedIDL?.instructions.isEmpty ?? true)

            HStack {
                Button("Preview Generated Files") {
                    onPrepareDrafts()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedIDL == nil)

                Button("Write Approved Drafts") {
                    onWriteDrafts()
                }
                .buttonStyle(.bordered)
                .disabled(frontendDrafts.isEmpty)
            }

            DeveloperWorkstationLabeledTextField(label: "Approval phrase", text: $writeApprovalPhrase, prompt: FrontendIntegrationService.writeApprovalPhrase)
            Text("Writing is blocked unless the exact phrase is entered. Existing files are not overwritten.")
                .font(.caption2)
                .foregroundStyle(GorkhColors.warning)
        }
    }

    @ViewBuilder
    private var generatedDraftPreview: some View {
        if !frontendDrafts.isEmpty {
            GorkhPanel("Generated Draft Preview") {
                ForEach(frontendDrafts) { draft in
                    DisclosureGroup(draft.relativePath) {
                        keyValue("Kind", draft.kind.title)
                        keyValue("Dependency style", draft.dependencyStyle)
                        if let warning = draft.warning {
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ScrollView(.horizontal) {
                            Text(draft.content)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(GorkhColors.primaryText)
                                .textSelection(.enabled)
                                .padding(10)
                                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var frontendEvidencePanel: some View {
        if let latest = frontendEvidence.first {
            GorkhPanel("Frontend Evidence") {
                keyValue("Latest", latest.summary)
                keyValue("Instruction", latest.selectedInstruction ?? "Not instruction-specific")
                ForEach(latest.files) { file in
                    HStack {
                        statusChip(file.status.title, color: file.status == .written ? GorkhColors.success : GorkhColors.warning)
                        Text(file.relativePath)
                            .font(.caption)
                        Spacer()
                        Button("Reveal") {
                            onRevealGeneratedFile(file.relativePath)
                        }
                        .buttonStyle(.bordered)
                        .disabled(file.status != .written)
                    }
                }
            }
        }
    }

    private func reportPanel(_ report: WorkstationV2Report) -> some View {
        GorkhPanel(report.capability.title) {
            WorkstationStatusChip(
                title: report.status.title,
                systemImage: report.status == .ready ? "checkmark.circle" : "exclamationmark.triangle",
                color: statusColor(report.status)
            )
            Text(report.summary)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if !report.evidence.isEmpty {
                DisclosureGroup("Evidence") {
                    ForEach(report.evidence, id: \.self) { item in
                        DeveloperWorkstationScrollingMonospacedText(value: item)
                    }
                }
            }
            if !report.findings.isEmpty {
                DisclosureGroup("Findings") {
                    ForEach(report.findings) { finding in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                WorkstationStatusChip(
                                    title: finding.severity.title,
                                    systemImage: finding.severity == .high || finding.severity == .medium ? "exclamationmark.triangle" : "info.circle",
                                    color: severityColor(finding.severity)
                                )
                                Text(finding.title)
                                    .fontWeight(.semibold)
                            }
                            Text(finding.detail)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if let evidence = finding.evidence {
                                DeveloperWorkstationScrollingMonospacedText(value: evidence)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            if !report.nextActions.isEmpty {
                DisclosureGroup("Safe next actions") {
                    ForEach(report.nextActions, id: \.self) { action in
                        Text(action)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
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

    private func severityColor(_ severity: WorkstationV2FindingSeverity) -> Color {
        switch severity {
        case .info, .low:
            return GorkhColors.success
        case .medium, .high:
            return GorkhColors.warning
        }
    }

    private func frontendSeverityColor(_ severity: FrontendAssistantSeverity) -> Color {
        switch severity {
        case .info, .low:
            return GorkhColors.success
        case .medium, .high:
            return GorkhColors.warning
        }
    }

    private func statusChip(_ title: String, color: Color) -> some View {
        WorkstationStatusChip(title: title, systemImage: "info.circle", color: color)
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        DeveloperWorkstationKeyValueRow(key: key, value: value)
    }

    private func fallback(_ value: String, _ fallback: String) -> String {
        value.isEmpty ? fallback : value
    }
}
