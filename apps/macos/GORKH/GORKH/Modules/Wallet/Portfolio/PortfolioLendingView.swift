import SwiftUI

struct PortfolioLendingView: View {
    let summary: LendingPortfolioSummary

    var body: some View {
        GorkhPanel("Lending") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: summary.status.title,
                        systemImage: icon(for: summary.status),
                        color: color(for: summary.status)
                    )
                    GorkhStatusChip(title: "Read-only", systemImage: "eye", color: GorkhColors.accent)
                    GorkhStatusChip(title: "Execution locked", systemImage: "lock", color: GorkhColors.warning)
                }

                Text(summary.noDoubleCountNotice)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], alignment: .leading, spacing: 10) {
                    metric("Supplied", value: currency(summary.suppliedValueUSD))
                    metric("Borrowed", value: currency(summary.borrowedValueUSD))
                    metric("Net Lending", value: currency(summary.netValueUSD))
                    metric("Positions", value: "\(summary.positionCount)")
                    metric("Risky", value: "\(summary.riskyPositionCount)")
                    metric("Unavailable", value: "\(summary.unavailableAdapterCount)")
                    metric("Markets", value: "\(summary.marketReserveCount)")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(summary.protocols) { protocolSummary in
                        LendingProtocolCardView(summary: protocolSummary)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(LendingLockedAction.allCases) { action in
                        Button {
                        } label: {
                            Label(action.title, systemImage: "lock")
                        }
                        .buttonStyle(.gorkhSecondary)
                        .disabled(!action.isEnabled)
                    }
                }
            }
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

    private func currency(_ value: Decimal?) -> String {
        value?.portfolioCurrencyText ?? "Unavailable"
    }

    private func icon(for status: LendingAdapterStatus) -> String {
        switch status {
        case .loaded:
            return "checkmark.seal"
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

    private func color(for status: LendingAdapterStatus) -> Color {
        switch status {
        case .loaded, .empty:
            return GorkhColors.success
        case .unavailable, .stale, .idle:
            return GorkhColors.warning
        case .error:
            return GorkhColors.danger
        }
    }
}

private struct LendingProtocolCardView: View {
    let summary: LendingProtocolSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.protocolKind.displayName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Spacer()
                GorkhStatusChip(
                    title: summary.status.title,
                    systemImage: summary.status == .loaded ? "checkmark" : "info.circle",
                    color: statusColor
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                row("Supplied", value: currency(summary.suppliedValueUSD))
                row("Borrowed", value: currency(summary.borrowedValueUSD))
                row("Net", value: currency(summary.netValueUSD))
                row("Wallets", value: "\(summary.walletCount)")
                row("Risky", value: "\(summary.riskyPositionCount)")
                row("Markets", value: "\(summary.marketReserveCount)")
                row("Source", value: summary.source.rawValue)
            }

            if !summary.positions.isEmpty {
                LendingPositionTableView(positions: summary.positions)
            } else if !summary.marketReserves.isEmpty {
                LendingMarketReserveListView(reserves: Array(summary.marketReserves.prefix(4)))
            } else {
                Text(summary.errorMessage ?? "No positions returned.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch summary.status {
        case .loaded, .empty:
            return GorkhColors.success
        case .unavailable, .stale, .idle:
            return GorkhColors.warning
        case .error:
            return GorkhColors.danger
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func currency(_ value: Decimal?) -> String {
        value?.portfolioCurrencyText ?? "Unavailable"
    }
}

private struct LendingMarketReserveListView: View {
    let reserves: [LendingMarketReserveSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Market context")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(GorkhColors.primaryText)
            ForEach(reserves) { reserve in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(reserve.symbol)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(GorkhColors.primaryText)
                        Spacer()
                        Text("Supply \(percent(reserve.supplyAPY))")
                            .font(.caption2)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                    Text("Borrow \(percent(reserve.borrowAPY)) / Utilization \(percent(reserve.utilization))")
                        .font(.caption2)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
    }

    private func percent(_ value: Decimal?) -> String {
        guard let value else {
            return "Unavailable"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "Unavailable"
    }
}

private struct LendingPositionTableView: View {
    let positions: [LendingPositionSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(positions) { position in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(position.walletLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(GorkhColors.primaryText)
                        Spacer()
                        LendingRiskBadgeView(level: position.health.riskLevel)
                    }
                    Text("\(position.suppliedAssets.count) supplied / \(position.borrowedAssets.count) borrowed")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
    }
}

private struct LendingRiskBadgeView: View {
    let level: LendingRiskLevel

    var body: some View {
        GorkhStatusChip(title: level.title, systemImage: "gauge", color: color)
    }

    private var color: Color {
        switch level {
        case .healthy:
            return GorkhColors.success
        case .caution, .unavailable:
            return GorkhColors.warning
        case .highRisk, .liquidationRisk:
            return GorkhColors.danger
        }
    }
}
