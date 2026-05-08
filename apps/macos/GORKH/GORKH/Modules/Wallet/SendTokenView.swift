import SwiftUI

struct SendTokenView: View {
    @EnvironmentObject private var walletManager: WalletManager
    let token: TokenBalance
    let onClose: () -> Void

    @State private var recipient = ""
    @State private var amount = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(GorkhColors.border)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Send \(token.displayLabel)")
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("Available \(token.uiAmountString), decimals \(token.decimals)")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close token send")
            }

            if walletManager.selectedNetwork.isMainnet {
                Text("Mainnet token sends can move real funds and require the exact confirmation phrase.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }

            TextField("Recipient owner address", text: $recipient)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            TextField("Amount", text: $amount)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    Task {
                        await walletManager.draftTokenTransfer(
                            token: token,
                            recipient: recipient,
                            amountText: amount
                        )
                    }
                } label: {
                    Label("Prepare Token Draft", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.gorkhPrimary)
                .disabled(walletManager.vaultState != .unlocked || walletManager.isBusy || !token.canSend)

                Button {
                    Task { await walletManager.simulateCurrentTokenDraft() }
                } label: {
                    Label("Simulate", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.gorkhSecondary)
                .disabled(walletManager.currentTokenDraft?.sourceTokenAccount != token.tokenAccountAddress || walletManager.currentTokenDraft?.recipientTokenAccount == nil || walletManager.isBusy)
            }

            if let draft = walletManager.currentTokenDraft,
               draft.sourceTokenAccount == token.tokenAccountAddress {
                TokenTransferDraftSummaryView(draft: draft, simulation: walletManager.tokenSimulationResult)
                TokenTransferApprovalView(draft: draft)
            }
        }
    }
}

private struct TokenTransferDraftSummaryView: View {
    let draft: TokenTransferDraft
    let simulation: SimulationResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Network", draft.network.displayName)
            row("Token program", draft.tokenProgramKind.displayName)
            row("Mint", draft.mintAddress)
            row("Source", draft.sourceTokenAccount)
            row("Recipient owner", draft.recipientOwnerAddress)
            row("Recipient token account", draft.recipientTokenAccount ?? "Missing")
            row("Amount", "\(draft.formattedAmount) (\(draft.amountRaw) raw)")
            row("ATA plan", draft.ataPlan.message)

            if let rent = draft.ataPlan.rentExemptLamports, draft.ataPlan.shouldCreateAssociatedTokenAccount {
                row("Rent estimate", "\(rent) lamports")
            }

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
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.system(.callout, design: title == "Amount" || title == "Network" || title == "Token program" || title == "Simulation" || title == "Estimated fee" || title == "Rent estimate" ? .default : .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
