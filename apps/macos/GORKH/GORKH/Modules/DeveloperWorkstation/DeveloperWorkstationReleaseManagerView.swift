import SwiftUI

struct DeveloperWorkstationReleaseManagerView: View {
    let activeProject: WorkstationProject?
    let parsedIDL: WorkstationIDL?
    let programEvidence: [WorkstationProgramOperationEvidence]
    let selectedCluster: WorkstationCluster

    var body: some View {
        let report = WorkstationReleaseManagerService.report(
            project: activeProject,
            idl: parsedIDL,
            evidence: programEvidence,
            cluster: selectedCluster
        )
        VStack(alignment: .leading, spacing: 14) {
            DeveloperWorkstationV2ReportPanel(report: report)
            GorkhPanel("Release Boundary") {
                DeveloperWorkstationKeyValueRow(key: "Selected cluster", value: selectedCluster.title)
                DeveloperWorkstationKeyValueRow(key: "Program writes", value: selectedCluster.programOpsMode.title)
                DeveloperWorkstationKeyValueRow(key: "Mainnet", value: "Mainnet program deploy/upgrade/close/authority mutation remains intentionally locked.")
                DeveloperWorkstationKeyValueRow(key: "Evidence store", value: "Redacted JSON only; no temp keypair contents or command environment.")
                Text("Release records can be partial when evidence, IDL path, artifact path, upgrade authority, or git metadata is unavailable.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DeveloperWorkstationV2ReportPanel: View {
    let report: WorkstationV2Report

    var body: some View {
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
}
