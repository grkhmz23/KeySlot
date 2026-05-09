import SwiftUI

struct YieldProtocolCardView: View {
    let protocolKind: YieldProtocol
    let opportunities: [YieldOpportunity]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(protocolKind.displayName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Spacer()
                GorkhStatusChip(title: status.title, systemImage: statusIcon, color: statusColor)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                metric("Sources", "\(opportunities.count)")
                metric("Held", "\(opportunities.filter(\.isHeld).count)")
                metric("Rate available", "\(opportunities.filter { $0.rate.value != nil }.count)")
                metric("Unavailable", "\(opportunities.filter { $0.rate.value == nil }.count)")
            }

            YieldOpportunityTableView(opportunities: opportunities)
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var status: YieldDataStatus {
        if opportunities.contains(where: { $0.status == .loaded }) {
            return opportunities.contains(where: { $0.status == .partial || $0.status == .unavailable || $0.status == .stale }) ? .partial : .loaded
        }
        if opportunities.contains(where: { $0.status == .partial }) {
            return .partial
        }
        if opportunities.contains(where: { $0.status == .error }) {
            return .error
        }
        if opportunities.allSatisfy({ $0.status == .unavailable }) {
            return .unavailable
        }
        return .stale
    }

    private var statusIcon: String {
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

    private var statusColor: Color {
        switch status {
        case .loaded, .empty:
            return GorkhColors.success
        case .partial, .unavailable, .stale, .idle:
            return GorkhColors.warning
        case .error:
            return GorkhColors.danger
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.caption)
                .foregroundStyle(GorkhColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
