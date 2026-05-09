import SwiftUI

struct PortfolioLiquidityView: View {
    let summary: LPPortfolioSummary

    var body: some View {
        GorkhPanel("Liquidity") {
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
                    metric("LP Value", value: currency(summary.estimatedValueUSD))
                    metric("Positions", value: "\(summary.positionCount)")
                    metric("Wallets", value: "\(summary.walletCount)")
                    metric("Partial adapters", value: "\(summary.partialAdapterCount)")
                    metric("Partial positions", value: "\(summary.partialPositionCount)")
                    metric("Unavailable", value: "\(summary.unavailableAdapterCount)")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(summary.protocols) { protocolSummary in
                        LPProtocolCardView(summary: protocolSummary)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(LPLockedAction.allCases) { action in
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

    private func icon(for status: LPAdapterStatus) -> String {
        switch status {
        case .loaded:
            return "checkmark.seal"
        case .empty:
            return "tray"
        case .partial:
            return "exclamationmark.magnifyingglass"
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

    private func color(for status: LPAdapterStatus) -> Color {
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

private struct LPProtocolCardView: View {
    let summary: LPProtocolSummary

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
                row("Value", value: currency(summary.estimatedValueUSD))
                row("Positions", value: "\(summary.positionCount)")
                row("Partial positions", value: "\(summary.partialPositionCount)")
                row("Wallets", value: "\(summary.walletCount)")
                row("Source", value: summary.source.rawValue)
                if summary.protocolKind == .meteora {
                    row("SDK method", value: "DLMM.getAllLbPairPositionsByUser")
                }
            }

            if !summary.positions.isEmpty {
                LPPositionTableView(positions: summary.positions)
            } else {
                Text(emptyMessage)
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
        case .partial, .unavailable, .stale, .idle:
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

    private var emptyMessage: String {
        summary.errorMessage ?? "No LP positions returned."
    }
}

private struct LPPositionTableView: View {
    let positions: [LPPositionSummary]

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
                        GorkhStatusChip(title: position.rangeSummary.state.title, systemImage: "arrow.left.and.right", color: rangeColor(position.rangeSummary.state))
                    }
                    Text("\(position.protocolKind.displayName) pool \(position.poolAddress.shortAddress) / position \(position.positionAddress.shortAddress)")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text(assetText(position))
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    if let metadataStatus = position.metadataStatus {
                        Text(metadataStatus)
                            .font(.caption2)
                            .foregroundStyle(GorkhColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func assetText(_ position: LPPositionSummary) -> String {
        let tokenA = assetSummary(position.tokenA)
        let tokenB = assetSummary(position.tokenB)
        let value = position.estimatedValueUSD?.portfolioCurrencyText ?? "value unavailable"
        return "\(tokenA) / \(tokenB) - \(value)"
    }

    private func assetSummary(_ asset: LPPositionAssetAmount?) -> String {
        guard let asset else {
            return "asset unavailable"
        }
        let amount = asset.uiAmountString ?? "amount unavailable"
        return "\(amount) \(asset.symbol)"
    }

    private func rangeColor(_ state: LPRangeState) -> Color {
        switch state {
        case .inRange:
            return GorkhColors.success
        case .outOfRange:
            return GorkhColors.warning
        case .unknown:
            return GorkhColors.secondaryText
        }
    }
}
