import SwiftUI

struct SendTokenView: View {
    @EnvironmentObject private var walletManager: WalletManager
    let token: TokenBalance
    let onClose: () -> Void

    @State private var recipient = ""
    @State private var amount = ""

    private func consumePendingDraftIfNeeded() {
        guard let draft = walletManager.pendingSendDraft else { return }
        // Only prefill if the draft token matches this token view (or no token specified but not SOL)
        let draftTokenUpper = draft.token?.uppercased()
        let metadata = TokenMetadataResolver.resolve(balance: token, network: walletManager.selectedNetwork)
        let matchesToken = draftTokenUpper == nil || draftTokenUpper == metadata.symbol.uppercased()
        guard matchesToken else { return }
        if !draft.recipient.isEmpty {
            recipient = draft.recipient
        }
        if !draft.amount.isEmpty {
            amount = draft.amount
        }
        walletManager.pendingSendDraft = nil
    }

    var body: some View {
        let metadata = TokenMetadataResolver.resolve(balance: token, network: walletManager.selectedNetwork)
        let warnings = TokenMetadataResolver.warnings(for: token, metadata: metadata)
        let canPrepare = TokenMetadataResolver.canSend(balance: token, metadata: metadata)

        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(GorkhColors.border)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Send \(metadata.displayTitle)")
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("Available \(token.uiAmountString), decimals \(metadata.decimals.map(String.init) ?? "unavailable")")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("Mint \(token.mintAddress.shortAddress) / \(token.programKind.displayName)")
                        .font(.system(.caption, design: .monospaced))
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

            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(warnings) { warning in
                        Text("\(warning.blocksSend ? "Blocked" : "Caution"): \(warning.message)")
                            .font(.caption)
                            .foregroundStyle(warning.blocksSend ? GorkhColors.danger : GorkhColors.warning)
                    }
                }
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
                .buttonStyle(.keyslotPrimary)
                .disabled(walletManager.vaultState != .unlocked || walletManager.isBusy || !canPrepare)

                Button {
                    Task { await walletManager.simulateCurrentTokenDraft() }
                } label: {
                    Label("Simulate", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.keyslotSecondary)
                .disabled(walletManager.currentTokenDraft?.sourceTokenAccount != token.tokenAccountAddress || walletManager.currentTokenDraft?.recipientTokenAccount == nil || walletManager.isBusy)
            }

            if let draft = walletManager.currentTokenDraft,
               draft.sourceTokenAccount == token.tokenAccountAddress {
                TokenTransferDraftSummaryView(draft: draft, simulation: walletManager.tokenSimulationResult)
                TokenTransferApprovalView(draft: draft)
            }
        }
        .onAppear {
            consumePendingDraftIfNeeded()
        }
    }
}

private struct TokenTransferDraftSummaryView: View {
    let draft: TokenTransferDraft
    let simulation: SimulationResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Network", draft.network.displayName)
            row("Token", draft.tokenDisplayName)
            row("Token program", draft.tokenProgramKind.displayName)
            row("Mint", draft.mintAddress)
            row("Source", draft.sourceTokenAccount)
            row("Source state", draft.sourceAccountState.rawValue)
            row("Recipient owner", draft.recipientOwnerAddress)
            row("Recipient token account", draft.recipientTokenAccount ?? "Missing")
            row("ATA creation", draft.ataPlan.shouldCreateAssociatedTokenAccount ? "Included before transfer" : "Not needed")
            row("Amount", "\(draft.formattedAmount) (\(draft.amountRaw) raw)")
            row("ATA plan", draft.ataPlan.message)
            if !draft.warnings.isEmpty {
                row("Warnings", draft.warnings.map(\.title).joined(separator: ", "))
            }

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
                .font(.system(.callout, design: title == "Amount" || title == "Network" || title == "Token program" || title == "Simulation" || title == "Estimated fee" || title == "Rent estimate" || title == "ATA creation" ? .default : .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
