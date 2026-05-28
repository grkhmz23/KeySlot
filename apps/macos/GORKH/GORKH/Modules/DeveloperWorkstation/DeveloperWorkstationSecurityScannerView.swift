import SwiftUI

struct DeveloperWorkstationSecurityScannerView: View {
    let activeProject: WorkstationProject?
    let report: SecurityScanReport?
    let isScanning: Bool
    let message: String
    @Binding var severityFilter: String
    @Binding var statusFilter: String
    @Binding var textFilter: String
    @Binding var dismissalReason: String
    let dateFormatter: DateFormatter
    let onRunScan: () -> Void
    let onDismissFinding: (String) -> Void
    let onCopyReport: () -> Void
    let onRecordReview: (SecurityScanReport) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerPanel

            if let report {
                summaryCards(report)
                filtersPanel
                findingsPanel(report)
                evidencePanel(report)
            } else {
                GorkhPanel("No Security Scan") {
                    Text("Import a folder project and press Run Scan. Untrusted projects can be scanned because the scanner only reads bounded source files.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var headerPanel: some View {
        GorkhPanel("Security Scanner - Developer Review Assistant") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Developer Review Assistant for conservative static checks and triage. This is not a formal audit, can miss vulnerabilities, and can produce false positives.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        WorkstationStatusChip(title: "Read-only", systemImage: "eye", color: GorkhColors.success)
                        WorkstationStatusChip(title: "No external services", systemImage: "network.slash", color: GorkhColors.success)
                        WorkstationStatusChip(title: "Not a formal audit", systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                    }
                }

                Spacer()

                Button(isScanning ? "Scanning..." : "Run Scan", action: onRunScan)
                    .buttonStyle(.borderedProminent)
                    .disabled(activeProject == nil || isScanning)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("The scanner reads bounded project source files only. It does not run cargo, npm, Anchor, Solana CLI, package scripts, RPC writes, or external API calls. Findings are potential issues unless deterministic evidence is shown.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func summaryCards(_ report: SecurityScanReport) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], spacing: 10) {
            DeveloperWorkstationMetricCard(title: "Open high", value: "\(report.count(.high))", detail: "High severity potential issues")
            DeveloperWorkstationMetricCard(title: "Open medium", value: "\(report.count(.medium))", detail: "Needs review")
            DeveloperWorkstationMetricCard(title: "Open low", value: "\(report.count(.low))", detail: "Hardening suggestions")
            DeveloperWorkstationMetricCard(title: "Open info", value: "\(report.count(.info))", detail: "Context and boundaries")
            DeveloperWorkstationMetricCard(title: "Files", value: "\(report.scannedFileCount)", detail: "\(report.sourceLineCount) source lines")
            DeveloperWorkstationMetricCard(title: "Generated", value: dateFormatter.string(from: report.generatedAt), detail: "Redacted local evidence")
        }
    }

    private var filtersPanel: some View {
        GorkhPanel("Filters") {
            HStack(spacing: 10) {
                Picker("Severity", selection: $severityFilter) {
                    Text("All severities").tag("all")
                    ForEach(SecurityFindingSeverity.allCases) { severity in
                        Text(severity.title).tag(severity.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Picker("Status", selection: $statusFilter) {
                    Text("All statuses").tag("all")
                    ForEach(SecurityFindingStatus.allCases) { status in
                        Text(status.title).tag(status.rawValue)
                    }
                }
                .pickerStyle(.menu)

                DeveloperWorkstationLabeledTextField(label: "Search", text: $textFilter, prompt: "category, file, title, evidence")
            }
        }
    }

    private func findingsPanel(_ report: SecurityScanReport) -> some View {
        GorkhPanel("Findings") {
            let findings = filteredFindings(report)
            if findings.isEmpty {
                Text("No findings match the current filters.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            ForEach(findings) { finding in
                findingRow(finding)
            }
        }
    }

    private func evidencePanel(_ report: SecurityScanReport) -> some View {
        GorkhPanel("Evidence") {
            DeveloperWorkstationKeyValueRow(key: "Project", value: report.projectName)
            DeveloperWorkstationKeyValueRow(key: "Project root", value: report.projectRootDisplay)
            DeveloperWorkstationKeyValueRow(key: "Project Brain", value: report.projectBrainId?.uuidString ?? "Unavailable")
            DeveloperWorkstationKeyValueRow(key: "Read-only", value: report.readOnly ? "Yes" : "No")
            if !report.unsupportedFindings.isEmpty {
                DisclosureGroup("Unsupported / bounded scan notes") {
                    ForEach(report.unsupportedFindings) { finding in
                        DeveloperWorkstationKeyValueRow(key: finding.title, value: finding.reason)
                    }
                }
            }
            HStack {
                Button("Copy Redacted Scanner Report", action: onCopyReport)
                    .buttonStyle(.bordered)

                Button("Record Security Scan Review") {
                    onRecordReview(report)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func findingRow(_ finding: SecurityFinding) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                Text(finding.detail)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                DeveloperWorkstationKeyValueRow(key: "Category", value: finding.category)
                DeveloperWorkstationKeyValueRow(key: "Confidence", value: finding.confidence.title)
                DeveloperWorkstationKeyValueRow(key: "Source", value: sourceLine(finding.sourceRelativePath, finding.sourceLineStart))
                if let instruction = finding.relatedInstruction {
                    DeveloperWorkstationKeyValueRow(key: "Instruction", value: instruction)
                }
                if let account = finding.relatedAccount {
                    DeveloperWorkstationKeyValueRow(key: "Account", value: account)
                }
                DeveloperWorkstationScrollingMonospacedText(value: finding.evidence)
                Text(finding.suggestedFix)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
                    .fixedSize(horizontal: false, vertical: true)

                if finding.status == .dismissed {
                    DeveloperWorkstationKeyValueRow(key: "Dismissed reason", value: finding.falsePositiveReason ?? "No reason recorded")
                } else {
                    DeveloperWorkstationLabeledTextField(label: "Dismiss reason", text: $dismissalReason, prompt: "Explain why this finding is a false positive")
                    Button("Dismiss Finding") {
                        onDismissFinding(finding.id)
                    }
                    .buttonStyle(.bordered)
                    .disabled(dismissalReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.top, 5)
        } label: {
            HStack(spacing: 8) {
                WorkstationStatusChip(
                    title: finding.severity.title,
                    systemImage: finding.severity == .high || finding.severity == .medium ? "exclamationmark.triangle" : "info.circle",
                    color: severityColor(finding.severity)
                )
                WorkstationStatusChip(
                    title: finding.status.title,
                    systemImage: finding.status == .open ? "circle" : "checkmark.circle",
                    color: finding.status == .open ? GorkhColors.warning : GorkhColors.secondaryText
                )
                Text(finding.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
            }
        }
        .padding(.vertical, 5)
    }

    private func filteredFindings(_ report: SecurityScanReport) -> [SecurityFinding] {
        let text = textFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return report.findings.filter { finding in
            let severityMatches = severityFilter == "all" || finding.severity.rawValue == severityFilter
            let statusMatches = statusFilter == "all" || finding.status.rawValue == statusFilter
            let textMatches = text.isEmpty ||
                finding.title.lowercased().contains(text) ||
                finding.category.lowercased().contains(text) ||
                finding.detail.lowercased().contains(text) ||
                finding.evidence.lowercased().contains(text) ||
                (finding.sourceRelativePath?.lowercased().contains(text) ?? false)
            return severityMatches && statusMatches && textMatches
        }
    }

    private func sourceLine(_ path: String?, _ line: Int?) -> String {
        guard let path else { return "Unavailable" }
        if let line {
            return "\(path):\(line)"
        }
        return path
    }

    private func severityColor(_ severity: SecurityFindingSeverity) -> Color {
        switch severity {
        case .info, .low:
            return GorkhColors.secondaryText
        case .medium, .high:
            return GorkhColors.warning
        }
    }
}
