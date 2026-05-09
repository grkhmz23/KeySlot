import SwiftUI

struct TokenTransferApprovalView: View {
    @EnvironmentObject private var walletManager: WalletManager
    let draft: TokenTransferDraft

    @State private var mainnetConfirmation = ""
    @State private var completedDevnetSmoke = false
    @State private var allowUnavailableSimulation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(GorkhColors.border)

            Text("Token Approval")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)

            VStack(alignment: .leading, spacing: 6) {
                approvalRow("Network", draft.network.displayName)
                approvalRow("RPC", draft.network.rpcURL.absoluteString)
                approvalRow("Token", draft.tokenDisplayName)
                approvalRow("Mint", draft.mintAddress)
                approvalRow("Program", draft.tokenProgramKind.displayName)
                approvalRow("Source account", draft.sourceTokenAccount)
                approvalRow("Source state", draft.sourceAccountState.rawValue)
                approvalRow("Recipient owner", draft.recipientOwnerAddress)
                approvalRow("Recipient ATA", draft.recipientTokenAccount ?? "Missing")
                approvalRow("Amount", "\(draft.formattedAmount) (\(draft.amountRaw) raw)")
                if let fee = walletManager.tokenSimulationResult?.estimatedFeeLamports {
                    approvalRow("Estimated fee", "\(fee) lamports")
                }
                approvalRow("Simulation", walletManager.tokenSimulationResult?.status.rawValue ?? "missing")
            }

            if !draft.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(draft.warnings) { warning in
                        Text("\(warning.blocksSend ? "Blocked" : "Caution"): \(warning.message)")
                            .font(.caption)
                            .foregroundStyle(warning.blocksSend ? GorkhColors.danger : GorkhColors.warning)
                    }
                }
            }

            if draft.ataPlan.shouldCreateAssociatedTokenAccount {
                GorkhStatusChip(
                    title: "ATA creation included",
                    systemImage: "exclamationmark.triangle.fill",
                    color: GorkhColors.warning
                )
                Text(draft.ataPlan.message)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                if let rent = draft.ataPlan.rentExemptLamports {
                    Text("The sender pays rent/fees for ATA creation. Rent estimate: \(rent) lamports.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
            } else {
                GorkhStatusChip(
                    title: "Recipient ATA exists",
                    systemImage: "checkmark.seal",
                    color: GorkhColors.success
                )
            }

            if draft.network.isMainnet {
                VStack(alignment: .leading, spacing: 8) {
                    GorkhStatusChip(title: "Real mainnet token transfer", systemImage: "exclamationmark.triangle.fill", color: GorkhColors.warning)
                    TextField(TransactionApprovalPolicy.requiredMainnetConfirmation, text: $mainnetConfirmation)
                        .textFieldStyle(.roundedBorder)
                    Toggle("I have completed a devnet smoke send for this build.", isOn: $completedDevnetSmoke)
                        .toggleStyle(.checkbox)
                        .foregroundStyle(GorkhColors.warning)
                    Text("Token transfers can permanently move real funds on mainnet.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("Verify the RPC endpoint, token mint, recipient owner, ATA state, amount, and simulation before approving.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }

            if walletManager.tokenSimulationResult?.status == .unavailable {
                Toggle("I understand simulation is unavailable and still want to sign and send.", isOn: $allowUnavailableSimulation)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(GorkhColors.warning)
            }

            if let logs = walletManager.tokenSimulationResult?.logs, !logs.isEmpty {
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
                    await walletManager.approveAndSendToken(
                        mainnetConfirmation: mainnetConfirmation,
                        hasCompletedDevnetSmoke: completedDevnetSmoke,
                        allowsUnavailableSimulation: allowUnavailableSimulation
                    )
                }
            } label: {
                Label(
                    draft.network.isMainnet ? "Approve Mainnet, Sign Locally, and Send Token" : "Approve, Sign Locally, and Send Token",
                    systemImage: "signature"
                )
            }
            .buttonStyle(.gorkhPrimary)
            .disabled(!canApprove || walletManager.vaultState != .unlocked || walletManager.isBusy || draft.recipientTokenAccount == nil)

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
    }

    private var canApprove: Bool {
        TransactionApprovalPolicy.canApprove(
            network: draft.network,
            simulation: walletManager.tokenSimulationResult,
            mainnetConfirmation: mainnetConfirmation,
            hasCompletedDevnetSmoke: completedDevnetSmoke,
            allowsUnavailableSimulation: allowUnavailableSimulation
        ) && !draft.warnings.contains { $0.blocksSend }
    }

    private func approvalRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: title == "Token" || title == "Program" || title == "Source state" || title == "Amount" ? .default : .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
