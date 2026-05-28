import SwiftUI

struct SendSolView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var recipient = ""
    @State private var amount = ""

    private func consumePendingDraftIfNeeded() {
        guard let draft = walletManager.pendingSendDraft else { return }
        if !draft.recipient.isEmpty {
            recipient = draft.recipient
        }
        if !draft.amount.isEmpty {
            amount = draft.amount
        }
        walletManager.pendingSendDraft = nil
    }

    var body: some View {
        GorkhPanel("Send SOL") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GorkhStatusChip(
                        title: walletManager.selectedNetwork.displayName,
                        systemImage: walletManager.selectedNetwork.isMainnet ? "exclamationmark.triangle.fill" : "network",
                        color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent
                    )

                    if walletManager.vaultState != .unlocked {
                        GorkhStatusChip(title: "Unlock required", systemImage: "lock", color: GorkhColors.warning)
                    }
                }

                TextField("Recipient Solana address", text: $recipient)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                TextField("Amount in SOL", text: $amount)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button {
                        walletManager.draftTransaction(recipient: recipient, amountSOLText: amount)
                    } label: {
                        Label("Prepare Draft", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.keyslotPrimary)
                    .disabled(walletManager.vaultState != .unlocked || walletManager.isBusy)

                    Button {
                        Task { await walletManager.simulateCurrentDraft() }
                    } label: {
                        Label("Simulate", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.keyslotSecondary)
                    .disabled(walletManager.currentDraft == nil || walletManager.isBusy)
                }

                if let draft = walletManager.currentDraft {
                    TransactionDraftSummaryView(draft: draft, simulation: walletManager.simulationResult)
                    TransactionApprovalView()
                }
            }
            .onAppear {
                consumePendingDraftIfNeeded()
            }
        }
    }
}

private struct TransactionDraftSummaryView: View {
    let draft: TransactionDraft
    let simulation: SimulationResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(GorkhColors.border)

            row("From", draft.fromAddress)
            row("To", draft.toAddress)
            row("Amount", draft.amountSOLText)
            row("Network", draft.network.displayName)

            if let simulation {
                row("Simulation", simulation.status.rawValue.capitalized)
                if let estimatedFee = simulation.estimatedFeeLamports {
                    row("Estimated fee", "\(estimatedFee) lamports")
                }
                if let error = simulation.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.danger)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(.callout, design: title == "Amount" || title == "Network" || title == "Simulation" || title == "Estimated fee" ? .default : .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
