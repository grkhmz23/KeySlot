import SwiftUI

struct ShieldReviewCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var walletManager: WalletManager

    let summary: ShieldReviewSummary
    @State private var recordedAppearance = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label("Shield Review", systemImage: "shield.lefthalf.filled")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Spacer()
                GorkhStatusChip(title: summary.status.title, systemImage: statusIcon, color: statusColor)
                GorkhStatusChip(title: summary.riskLevel.title, systemImage: riskIcon, color: riskColor)
            }

            Text(summary.explanation)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                metric("Programs", value: summary.programLabels.isEmpty ? "Unavailable" : summary.programLabels.joined(separator: ", "))
                metric("Signers", value: "\(summary.signerCount)")
                metric("Writable", value: "\(summary.writableCount)")
                metric("Unknown", value: "\(summary.unknownInstructionCount)")
                metric("Simulation", value: summary.simulation.status.title)
            }

            if summary.parsedActions.isEmpty == false {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Recognized actions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.secondaryText)
                    ForEach(summary.parsedActions.prefix(4)) { action in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.label)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.primaryText)
                            Text(action.detail)
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                                .lineLimit(3)
                        }
                    }
                }
            }

            if summary.riskFlags.isEmpty == false {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Risk flags")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.secondaryText)
                    ForEach(summary.riskFlags.prefix(4)) { flag in
                        Label(flag.message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(color(for: flag.level))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    appState.requestTransactionStudioSummary(summary.handoff.safeSummary)
                    walletManager.recordShieldReviewEvent(
                        kind: .shieldReviewOpenedInStudio,
                        summary: summary,
                        message: "Shield Review opened in Transaction Studio."
                    )
                } label: {
                    Label("Open in Transaction Studio", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.gorkhSecondary)

                if summary.status == .unavailable {
                    Text(summary.unavailableReason ?? "Review unavailable.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                } else {
                    Text("Review only. Signing stays in this approval flow.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }

            DisclosureGroup("Details") {
                ShieldReviewDetailView(summary: summary)
                    .padding(.top, 6)
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("shieldReview.card")
        .onAppear {
            recordAppearanceIfNeeded()
        }
    }

    private var statusIcon: String {
        switch summary.status {
        case .ready:
            return "checkmark.seal"
        case .unavailable:
            return "exclamationmark.triangle"
        case .externalSummary:
            return "arrow.up.forward.square"
        }
    }

    private var statusColor: Color {
        switch summary.status {
        case .ready:
            return GorkhColors.success
        case .unavailable, .externalSummary:
            return GorkhColors.warning
        }
    }

    private var riskIcon: String {
        switch summary.riskLevel {
        case .low:
            return "checkmark.shield"
        case .medium:
            return "exclamationmark.shield"
        case .high:
            return "xmark.shield"
        case .unknown:
            return "questionmark.diamond"
        }
    }

    private var riskColor: Color {
        color(for: summary.riskLevel)
    }

    private func color(for level: ShieldReviewRiskLevel) -> Color {
        switch level {
        case .low:
            return GorkhColors.success
        case .medium, .unknown:
            return GorkhColors.warning
        case .high:
            return GorkhColors.danger
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.system(.caption, design: title == "Programs" ? .default : .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recordAppearanceIfNeeded() {
        guard recordedAppearance == false else { return }
        recordedAppearance = true
        walletManager.recordShieldReviewEvent(
            kind: .shieldReviewGenerated,
            summary: summary,
            message: "Shield Review generated."
        )
        if summary.status == .unavailable {
            walletManager.recordShieldReviewEvent(
                kind: .shieldReviewUnavailable,
                summary: summary,
                message: "Shield Review unavailable."
            )
        }
        if summary.riskLevel == .high {
            walletManager.recordShieldReviewEvent(
                kind: .shieldReviewRiskHigh,
                summary: summary,
                message: "Shield Review marked high risk."
            )
        }
        if ShieldReviewPolicy.requiresBlockingReview(summary) {
            walletManager.recordShieldReviewEvent(
                kind: .shieldReviewApprovalBlocked,
                summary: summary,
                message: "Approval blocked by Shield Review."
            )
        }
    }
}
