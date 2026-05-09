import SwiftUI

struct PortfolioYieldView: View {
    @EnvironmentObject private var walletManager: WalletManager
    let summary: YieldPortfolioSummary
    @State private var didRecordView = false

    var body: some View {
        GorkhPanel("Yield") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(title: summary.status.title, systemImage: icon(for: summary.status), color: color(for: summary.status))
                    GorkhStatusChip(title: "Read-only analytics", systemImage: "chart.line.uptrend.xyaxis", color: GorkhColors.accent)
                    GorkhStatusChip(title: "Execution locked", systemImage: "lock", color: GorkhColors.warning)
                }

                Text(summary.noDoubleCountNotice)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                    metric("Yield Exposure", value: summary.totalYieldExposureUSD?.portfolioCurrencyText ?? "Unavailable")
                    metric("Held Sources", value: "\(summary.heldOpportunityCount)")
                    metric("Rates Available", value: "\(summary.apyAvailableCount)")
                    metric("Unavailable", value: "\(summary.unavailableCount)")
                    metric("Top Source", value: summary.topYieldSourceLabel ?? "Unavailable")
                }

                if !summary.holdings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current exposure")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(GorkhColors.primaryText)
                        ForEach(summary.holdings.prefix(8)) { holding in
                            HStack(spacing: 8) {
                                GorkhStatusChip(title: holding.sourceKind.title, systemImage: "circle.grid.2x2", color: GorkhColors.accent)
                                Text(holding.label)
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.primaryText)
                                Spacer()
                                Text(holding.estimatedUSD?.portfolioCurrencyText ?? "Value unavailable")
                                    .font(.caption)
                                    .foregroundStyle(holding.estimatedUSD == nil ? GorkhColors.warning : GorkhColors.primaryText)
                            }
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(protocolsWithOpportunities, id: \.self) { protocolKind in
                        YieldProtocolCardView(
                            protocolKind: protocolKind,
                            opportunities: summary.opportunities.filter { $0.protocolKind == protocolKind }
                        )
                    }
                }

                HStack(spacing: 8) {
                    lockedButton("Coming later")
                    lockedButton("No auto-yield")
                    lockedButton("Compare only")
                }

                Text("APY/APR is displayed only when an existing read-only source provides it. Cached protocol data can be stale and unavailable states are not filled with estimates.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            if !didRecordView {
                didRecordView = true
                walletManager.recordYieldPanelViewed()
            }
        }
    }

    private var protocolsWithOpportunities: [YieldProtocol] {
        YieldProtocol.allCases.filter { protocolKind in
            summary.opportunities.contains { $0.protocolKind == protocolKind }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.system(.callout, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lockedButton(_ title: String) -> some View {
        Button {
        } label: {
            Label(title, systemImage: "lock")
        }
        .buttonStyle(.gorkhSecondary)
        .disabled(true)
    }

    private func icon(for status: YieldDataStatus) -> String {
        switch status {
        case .loaded:
            return "checkmark.seal"
        case .partial:
            return "exclamationmark.magnifyingglass"
        case .empty:
            return "tray"
        case .unavailable:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        case .stale:
            return "clock.badge.exclamationmark"
        case .idle:
            return "clock"
        }
    }

    private func color(for status: YieldDataStatus) -> Color {
        switch status {
        case .loaded, .empty:
            return GorkhColors.success
        case .partial, .unavailable, .stale, .idle:
            return GorkhColors.warning
        case .error:
            return GorkhColors.danger
        }
    }
}
