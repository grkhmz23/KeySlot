import AppKit
import SwiftUI

struct PUSDTreasuryView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var isShowingSend = false
    @State private var isShowingReceive = false
    @State private var paymentAmount = ""
    @State private var didRecordView = false

    private var summary: PUSDTreasurySummary {
        walletManager.portfolioSummary.pusdTreasurySummary
    }

    var body: some View {
        GorkhPanel("PUSD Treasury") {
            VStack(alignment: .leading, spacing: 14) {
                header
                metrics
                copyBlock
                actions
                circulation
                lockedFuture

                if isShowingSend, let token = walletManager.activePUSDTokenBalance {
                    SendTokenView(token: token) {
                        isShowingSend = false
                    }
                }

                if isShowingReceive {
                    receivePanel
                }
            }
        }
        .task {
            if !didRecordView {
                didRecordView = true
                walletManager.recordPUSDTreasuryViewed()
            }
            if walletManager.pusdCirculationSnapshot.status == .idle {
                await walletManager.refreshPUSDCirculation()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GorkhStatusChip(title: "Stablecoin", systemImage: "dollarsign.circle", color: GorkhColors.success)
                    GorkhStatusChip(title: "Mainnet SPL", systemImage: "circle.hexagongrid", color: GorkhColors.accent)
                    GorkhStatusChip(title: "No mint/redeem", systemImage: "lock", color: GorkhColors.warning)
                }
                Text(PUSDConstants.integrationDescription)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(PUSDConstants.mintRedeemDescription)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(summary.uiAmountString)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(GorkhColors.primaryText)
                Text("PUSD total")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
            metric("Estimated USD", summary.estimatedUSD?.portfolioCurrencyText ?? "Unavailable")
            metric("Price source", summary.priceSource.title)
            metric("Wallets holding", "\(summary.holdingWalletCount)")
            metric("Watch-only", "\(summary.watchOnlyUIAmountString) PUSD")
            metric("Mint", summary.mintAddress.shortAddress)
            metric("Decimals", "\(summary.decimals)")
        }
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.priceSourceDescription)
                .font(.caption)
                .foregroundStyle(summary.priceSource == .stablecoinPegEstimate ? GorkhColors.warning : GorkhColors.secondaryText)
            Text("PUSD values are treasury estimates. KeySlot does not call reserves or peg endpoints until Palm publishes them as live.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                isShowingSend.toggle()
            } label: {
                Label("Send PUSD", systemImage: "paperplane")
            }
            .buttonStyle(.keyslotPrimary)
            .disabled(walletManager.activePUSDTokenBalance == nil || walletManager.vaultState != .unlocked || walletManager.isBusy)
            .help(sendHelp)

            Button {
                isShowingReceive.toggle()
                if !isShowingReceive {
                    return
                }
                walletManager.recordPUSDReceiveViewed()
            } label: {
                Label("Receive PUSD", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.keyslotSecondary)
            .disabled(walletManager.selectedProfile == nil)

            if summary.hasBalance == false {
                Text("No active PUSD balance. Use Receive PUSD or request a manual Swap quote; nothing executes automatically.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private var circulation: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Circulation")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                GorkhStatusChip(
                    title: walletManager.pusdCirculationSnapshot.status.title,
                    systemImage: walletManager.pusdCirculationSnapshot.status == .loaded ? "checkmark.seal" : "clock",
                    color: walletManager.pusdCirculationSnapshot.status == .loaded ? GorkhColors.success : GorkhColors.warning
                )
                Spacer()
                Button {
                    Task { await walletManager.refreshPUSDCirculation(forceRefresh: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.keyslotSecondary)
                .disabled(walletManager.pusdCirculationSnapshot.status == .loading)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                metric("Total circulating", decimalText(walletManager.pusdCirculationSnapshot.totalCirculating))
                metric("Solana circulating", decimalText(walletManager.pusdCirculationSnapshot.solanaCirculating))
                metric("Chains", "\(walletManager.pusdCirculationSnapshot.chainTotals.count)")
                metric("Updated", walletManager.pusdCirculationSnapshot.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unavailable")
            }

            if let error = walletManager.pusdCirculationSnapshot.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var lockedFuture: some View {
        HStack(spacing: 8) {
            ForEach(summary.lockedFutureActions) { action in
                GorkhStatusChip(title: action.title, systemImage: "lock", color: GorkhColors.warning)
            }
        }
    }

    private var receivePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .overlay(GorkhColors.border)

            Text("Receive / Payment Request")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)

            if walletManager.selectedNetwork != .mainnetBeta {
                Text("PUSD is configured for Solana mainnet-beta only. Switch to Mainnet before sharing a PUSD payment request.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }

            if let profile = walletManager.selectedProfile {
                row("Wallet address", profile.publicAddress)
                row("PUSD mint", PUSDConstants.mintAddress)

                TextField("Optional amount", text: $paymentAmount)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)

                HStack(spacing: 8) {
                    Button {
                        copy(profile.publicAddress)
                    } label: {
                        Label("Copy Address", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.keyslotSecondary)

                    Button {
                        copy(paymentNote(address: profile.publicAddress))
                    } label: {
                        Label("Copy Payment Note", systemImage: "text.quote")
                    }
                    .buttonStyle(.keyslotSecondary)
                }
            }
        }
        .padding(10)
        .background(GorkhColors.panelElevated.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sendHelp: String {
        if walletManager.activePUSDTokenBalance == nil {
            return "Active wallet has no initialized PUSD token account with balance."
        }
        if walletManager.vaultState != .unlocked {
            return "Unlock the wallet to use the existing SPL send flow."
        }
        return "Uses the existing SPL token send approval path."
    }

    private func metric(_ title: String, _ value: String) -> some View {
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

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func decimalText(_ value: Decimal?) -> String {
        value.map { "\($0) PUSD" } ?? "Unavailable"
    }

    private func paymentNote(address: String) -> String {
        let trimmedAmount = paymentAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAmount.isEmpty {
            return "Pay PUSD on Solana mainnet to \(address). Mint: \(PUSDConstants.mintAddress)"
        }
        return "Pay \(trimmedAmount) PUSD on Solana mainnet to \(address). Mint: \(PUSDConstants.mintAddress)"
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
