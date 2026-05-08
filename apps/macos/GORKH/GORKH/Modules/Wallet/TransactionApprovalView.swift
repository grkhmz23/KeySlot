import SwiftUI

struct TransactionApprovalView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var mainnetConfirmation = ""
    @State private var completedDevnetSmoke = false
    @State private var allowUnavailableSimulation = false

    var body: some View {
        guard let draft = walletManager.currentDraft else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .overlay(GorkhColors.border)

                Text("Approval")
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)

                if draft.network.isMainnet {
                    VStack(alignment: .leading, spacing: 8) {
                        GorkhStatusChip(title: "Real mainnet transaction", systemImage: "exclamationmark.triangle.fill", color: GorkhColors.warning)
                        TextField(TransactionApprovalPolicy.requiredMainnetConfirmation, text: $mainnetConfirmation)
                            .textFieldStyle(.roundedBorder)
                        Toggle("I have completed a devnet smoke send for this build.", isOn: $completedDevnetSmoke)
                            .toggleStyle(.checkbox)
                            .foregroundStyle(GorkhColors.warning)
                        Text("Mainnet is present for review only until this build has proven key compatibility and transaction serialization on devnet.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }

                if walletManager.simulationResult?.status == .unavailable {
                    Toggle("I understand simulation is unavailable and still want to sign and send.", isOn: $allowUnavailableSimulation)
                        .toggleStyle(.checkbox)
                        .foregroundStyle(GorkhColors.warning)
                }

                if let logs = walletManager.simulationResult?.logs, !logs.isEmpty {
                    DisclosureGroup("Simulation logs") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(logs.prefix(12), id: \.self) { line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(GorkhColors.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                Button {
                    Task {
                        await walletManager.approveAndSend(
                            mainnetConfirmation: mainnetConfirmation,
                            hasCompletedDevnetSmoke: completedDevnetSmoke,
                            allowsUnavailableSimulation: allowUnavailableSimulation
                        )
                    }
                } label: {
                    Label("Approve, Sign Locally, and Send", systemImage: "signature")
                }
                .buttonStyle(.gorkhPrimary)
                .disabled(!canApprove(draft: draft) || walletManager.vaultState != .unlocked || walletManager.isBusy)

                if let signature = walletManager.lastTransactionSignature {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Signature")
                            .foregroundStyle(GorkhColors.secondaryText)
                        Text(signature)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(GorkhColors.primaryText)
                            .textSelection(.enabled)

                        if let status = walletManager.lastConfirmationStatus {
                            Text("Confirmation: \(status)")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }

                        if let url = walletManager.explorerURLForLastSignature {
                            Link("Open in Solana Explorer", destination: url)
                                .font(.caption)
                        }
                    }
                }
            }
        )
    }

    private func canApprove(draft: TransactionDraft) -> Bool {
        TransactionApprovalPolicy.canApprove(
            network: draft.network,
            simulation: walletManager.simulationResult,
            mainnetConfirmation: mainnetConfirmation,
            hasCompletedDevnetSmoke: completedDevnetSmoke,
            allowsUnavailableSimulation: allowUnavailableSimulation
        )
    }
}
