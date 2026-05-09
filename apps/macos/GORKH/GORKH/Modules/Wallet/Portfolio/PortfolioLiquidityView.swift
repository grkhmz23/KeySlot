import SwiftUI

struct PortfolioLiquidityView: View {
    let summary: LPPortfolioSummary
    let harvestDraft: OrcaHarvestDraft?
    let harvestReview: OrcaHarvestReview?
    let harvestSimulation: SimulationResult?
    let harvestApprovalState: ApprovalState
    let harvestErrorMessage: String?
    @Binding var mainnetConfirmation: String
    @Binding var completedDevnetSmoke: Bool
    let prepareHarvestAction: (LPPositionSummary) -> Void
    let simulateHarvestAction: () -> Void
    let approveHarvestAction: () -> Void
    let resetHarvestAction: () -> Void

    init(
        summary: LPPortfolioSummary,
        harvestDraft: OrcaHarvestDraft? = nil,
        harvestReview: OrcaHarvestReview? = nil,
        harvestSimulation: SimulationResult? = nil,
        harvestApprovalState: ApprovalState = .idle,
        harvestErrorMessage: String? = nil,
        mainnetConfirmation: Binding<String> = .constant(""),
        completedDevnetSmoke: Binding<Bool> = .constant(false),
        prepareHarvestAction: @escaping (LPPositionSummary) -> Void = { _ in },
        simulateHarvestAction: @escaping () -> Void = {},
        approveHarvestAction: @escaping () -> Void = {},
        resetHarvestAction: @escaping () -> Void = {}
    ) {
        self.summary = summary
        self.harvestDraft = harvestDraft
        self.harvestReview = harvestReview
        self.harvestSimulation = harvestSimulation
        self.harvestApprovalState = harvestApprovalState
        self.harvestErrorMessage = harvestErrorMessage
        self._mainnetConfirmation = mainnetConfirmation
        self._completedDevnetSmoke = completedDevnetSmoke
        self.prepareHarvestAction = prepareHarvestAction
        self.simulateHarvestAction = simulateHarvestAction
        self.approveHarvestAction = approveHarvestAction
        self.resetHarvestAction = resetHarvestAction
    }

    var body: some View {
        GorkhPanel("Liquidity") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: summary.status.title,
                        systemImage: icon(for: summary.status),
                        color: color(for: summary.status)
                    )
                    GorkhStatusChip(title: "Harvest guarded", systemImage: "checkmark.shield", color: GorkhColors.accent)
                    GorkhStatusChip(title: "Add/remove locked", systemImage: "lock", color: GorkhColors.warning)
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
                        LPProtocolCardView(summary: protocolSummary, prepareHarvestAction: prepareHarvestAction)
                    }
                }

                OrcaHarvestApprovalPanel(
                    draft: harvestDraft,
                    review: harvestReview,
                    simulation: harvestSimulation,
                    approvalState: harvestApprovalState,
                    errorMessage: harvestErrorMessage,
                    mainnetConfirmation: $mainnetConfirmation,
                    completedDevnetSmoke: $completedDevnetSmoke,
                    simulateAction: simulateHarvestAction,
                    approveAction: approveHarvestAction,
                    resetAction: resetHarvestAction
                )

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

private struct OrcaHarvestApprovalPanel: View {
    let draft: OrcaHarvestDraft?
    let review: OrcaHarvestReview?
    let simulation: SimulationResult?
    let approvalState: ApprovalState
    let errorMessage: String?
    @Binding var mainnetConfirmation: String
    @Binding var completedDevnetSmoke: Bool
    let simulateAction: () -> Void
    let approveAction: () -> Void
    let resetAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Orca Harvest Approval")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Spacer()
                GorkhStatusChip(title: approvalStatusTitle, systemImage: "signature", color: approvalColor)
            }

            if let draft {
                HStack(spacing: 8) {
                    GorkhStatusChip(title: simulation?.status.rawValue ?? "not simulated", systemImage: "waveform.path.ecg", color: simulation?.status == .success ? GorkhColors.success : GorkhColors.warning)
                    GorkhStatusChip(title: "Mainnet real funds", systemImage: "exclamationmark.triangle.fill", color: GorkhColors.warning)
                    GorkhStatusChip(title: "Native signer only", systemImage: "lock.shield", color: GorkhColors.accent)
                }

                row("Wallet", draft.walletPublicAddress.shortAddress)
                row("Position mint", draft.positionMint)
                row("Pool", draft.poolAddress)
                row("Instructions", "\(review?.instructionCount ?? draft.plan.instructionCount)")
                row("Writable accounts", "\(review?.writableAccountCount ?? draft.plan.writableAccountCount)")
                row("Estimated fee", simulation?.estimatedFeeLamports.map { "\($0) lamports" } ?? "Unavailable")
                row("Review", review?.canApprove == true ? "passed" : "missing or blocked")

                if let warning = draft.plan.warning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Harvesting Orca fees/rewards is a real mainnet transaction. GORKH builds an unsigned proposal, reviews it locally, simulates it, then signs with the native wallet only after explicit approval.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                TextField(TransactionApprovalPolicy.requiredMainnetConfirmation, text: $mainnetConfirmation)
                    .textFieldStyle(.roundedBorder)
                Toggle("I have completed a devnet smoke send for this build.", isOn: $completedDevnetSmoke)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(GorkhColors.warning)

                if let logs = simulation?.logs, !logs.isEmpty {
                    DisclosureGroup("Simulation logs") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(logs.prefix(16), id: \.self) { line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(GorkhColors.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                HStack(spacing: 8) {
                    Button(action: simulateAction) {
                        Label("Simulate Harvest", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.gorkhSecondary)
                    .disabled(review?.canApprove != true)

                    Button(action: approveAction) {
                        Label("Approve, Authenticate, Sign Locally, and Send", systemImage: "signature")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(!(review?.canApprove == true && simulation?.status == .success))

                    Button(action: resetAction) {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.gorkhSecondary)
                }
            } else {
                Text("Select an Orca LP position and create a harvest plan before approval.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var approvalStatusTitle: String {
        switch approvalState {
        case .idle:
            return "idle"
        case .drafted:
            return "drafted"
        case .simulated:
            return "ready"
        case .approved:
            return "approved"
        case .sending:
            return "sending"
        case .sent:
            return "sent"
        case .failed:
            return "failed"
        }
    }

    private var approvalColor: Color {
        switch approvalState {
        case .simulated, .sent:
            return GorkhColors.success
        case .failed:
            return GorkhColors.danger
        case .idle, .drafted, .approved, .sending:
            return GorkhColors.warning
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}

private struct LPProtocolCardView: View {
    let summary: LPProtocolSummary
    let prepareHarvestAction: (LPPositionSummary) -> Void

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
                } else if summary.protocolKind == .orca {
                    row("SDK method", value: "fetchPositionsForOwner")
                }
            }

            if !summary.positions.isEmpty {
                LPPositionTableView(positions: summary.positions, prepareHarvestAction: prepareHarvestAction)
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
    let prepareHarvestAction: (LPPositionSummary) -> Void

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
                    if position.protocolKind == .orca {
                        HStack {
                            Button {
                                prepareHarvestAction(position)
                            } label: {
                                Label("Harvest fees/rewards", systemImage: "tray.and.arrow.down")
                            }
                            .buttonStyle(.gorkhSecondary)
                            .disabled(position.positionMintAddress == nil)

                            if position.positionMintAddress == nil {
                                Text("Position mint unavailable.")
                                    .font(.caption2)
                                    .foregroundStyle(GorkhColors.warning)
                            }
                        }
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
