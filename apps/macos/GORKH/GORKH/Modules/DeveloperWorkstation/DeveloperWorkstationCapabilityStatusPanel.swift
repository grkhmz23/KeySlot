import SwiftUI

struct DeveloperWorkstationCapabilityStatusPanel: View {
    let capabilities: [DeveloperWorkstationCapability]
    let manualQAItems: [DeveloperWorkstationManualQAItem]
    let onOpenSection: (DeveloperWorkstationSection) -> Void

    var body: some View {
        GorkhPanel("Capability & QA Status") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Developer Workstation availability, safety boundaries, and manual QA gaps. This is not a marketing checklist.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                capabilityGroup(
                    "Operational / Available",
                    capabilities.filter { $0.status == .operational }
                )
                capabilityGroup(
                    "Limited / Gated",
                    capabilities.filter { [.limited, .gated].contains($0.status) }
                )
                capabilityGroup(
                    "Detect-only / Unsupported",
                    capabilities.filter { [.detectOnly, .unsupported, .unavailable].contains($0.status) }
                )
                capabilityGroup(
                    "Manual QA Required",
                    capabilities.filter { $0.status == .manualQARequired }
                )

                Divider().overlay(GorkhColors.border)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Manual QA Required")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GorkhColors.primaryText)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                        ForEach(manualQAItems) { item in
                            manualQAItem(item)
                        }
                    }
                }
            }
        }
    }

    private func capabilityGroup(_ title: String, _ rows: [DeveloperWorkstationCapability]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GorkhColors.primaryText)
                Spacer()
                Text("\(rows.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            if rows.isEmpty {
                Text("No capabilities currently reported in this group.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(rows) { capability in
                        capabilityCard(capability)
                    }
                }
            }
        }
    }

    private func capabilityCard(_ capability: DeveloperWorkstationCapability) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(capability.limitations, id: \.self) { limitation in
                    Text("- \(limitation)")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let next = capability.nextSafeAction {
                    Text("Next safe action: \(next)")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let section = capability.relatedSection {
                    Button("Open \(section.title)") {
                        onOpenSection(section)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 6)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    capabilityChip(
                        title: capability.status.title,
                        systemImage: statusIcon(capability.status),
                        color: statusColor(capability.status)
                    )
                    capabilityChip(
                        title: "\(capability.risk.title) risk",
                        systemImage: "exclamationmark.triangle",
                        color: riskColor(capability.risk)
                    )
                    Spacer(minLength: 0)
                }
                Text(capability.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GorkhColors.primaryText)
                Text(capability.summary)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let first = capability.limitations.first {
                    Text(first)
                        .font(.caption2)
                        .foregroundStyle(GorkhColors.warning)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(GorkhColors.border))
            )
        }
        .tint(GorkhColors.primaryText)
    }

    private func manualQAItem(_ item: DeveloperWorkstationManualQAItem) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                capabilityChip(
                    title: item.status.title,
                    systemImage: manualQAIcon(item.status),
                    color: manualQAColor(item.status)
                )
                Spacer()
            }
            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GorkhColors.primaryText)
            Text(item.detail)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let section = item.relatedSection {
                Button("Open \(section.title)") {
                    onOpenSection(section)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(GorkhColors.border))
        )
    }

    private func capabilityChip(title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
            )
    }

    private func statusIcon(_ status: DeveloperWorkstationCapabilityStatus) -> String {
        switch status {
        case .operational:
            return "checkmark.circle"
        case .limited, .gated:
            return "lock.shield"
        case .detectOnly:
            return "eye"
        case .unsupported, .unavailable:
            return "xmark.octagon"
        case .manualQARequired:
            return "checklist"
        }
    }

    private func statusColor(_ status: DeveloperWorkstationCapabilityStatus) -> Color {
        switch status {
        case .operational:
            return GorkhColors.success
        case .limited, .gated, .detectOnly, .manualQARequired:
            return GorkhColors.warning
        case .unsupported, .unavailable:
            return GorkhColors.danger
        }
    }

    private func riskColor(_ risk: DeveloperWorkstationCapabilityRisk) -> Color {
        switch risk {
        case .low:
            return GorkhColors.success
        case .medium:
            return GorkhColors.warning
        case .high:
            return GorkhColors.danger
        }
    }

    private func manualQAIcon(_ status: DeveloperWorkstationManualQAStatus) -> String {
        switch status {
        case .notRun:
            return "clock"
        case .passed:
            return "checkmark.circle"
        case .failed:
            return "xmark.octagon"
        case .notApplicable:
            return "minus.circle"
        case .unavailable:
            return "lock"
        }
    }

    private func manualQAColor(_ status: DeveloperWorkstationManualQAStatus) -> Color {
        switch status {
        case .passed:
            return GorkhColors.success
        case .failed:
            return GorkhColors.danger
        case .notRun, .notApplicable, .unavailable:
            return GorkhColors.warning
        }
    }
}
