import SwiftUI

struct CloakDepositDraftView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var amountSOLText = "0.01"
    @State private var mainnetConfirmation = ""
    @State private var feeAcknowledged = false
    @State private var shieldReviewCompleted = false
    @State private var explicitApproval = false

    var body: some View {
        GorkhPanel("Shield SOL") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField("Amount SOL", text: $amountSOLText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)

                    Button {
                        walletManager.draftCloakSolDeposit(amountSOLText: amountSOLText)
                    } label: {
                        Label("Prepare Draft", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(walletManager.selectedProfile == nil)

                    Button {
                        Task { await walletManager.runCloakDepositPlanDryRun() }
                    } label: {
                        Label("Dry-run Plan", systemImage: "terminal")
                    }
                    .buttonStyle(.gorkhSecondary)
                    .disabled(walletManager.currentCloakDepositDraft == nil)

                    Spacer()

                    GorkhStatusChip(title: "Native signer", systemImage: "signature", color: GorkhColors.accent)
                }

                if let draft = walletManager.currentCloakDepositDraft {
                    draftSummary(draft)
                    approvalControls
                    Button {
                        Task {
                            await walletManager.executeCloakDeposit(
                                mainnetConfirmation: mainnetConfirmation,
                                feeAcknowledged: feeAcknowledged,
                                shieldReviewCompleted: shieldReviewCompleted,
                                explicitApproval: explicitApproval
                            )
                        }
                    } label: {
                        Label("Approve, Authenticate, Sign, and Shield SOL", systemImage: "lock.shield")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(!canExecuteDeposit)
                } else {
                    Text("Prepare a SOL amount to preview Cloak minimums, fixed fee, variable fee, and estimated private net amount.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                lockedActions

                if let response = walletManager.cloakBridgeResponse {
                    Text(response.message)
                        .font(.caption)
                        .foregroundStyle(response.status == .blocked || response.status == .failed ? GorkhColors.danger : GorkhColors.secondaryText)
                }
            }
        }
    }

    private func draftSummary(_ draft: CloakDepositDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                metric("Gross", value: draft.feeQuote.grossSOLText)
                metric("Withdraw fee model", value: draft.feeQuote.totalFeeSOLText)
                metric("Shielded amount", value: draft.feeQuote.grossSOLText)
            }

            Text(draft.networkWarning ?? "")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
            Text("Cloak deposits shield the full deposit amount. The fixed and variable fee model applies to SOL withdraw/send paths.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text("Private state from a confirmed deposit is stored in the local Cloak vault. GORKH cannot recover it if the local vault is deleted.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text("Source \(draft.sourceWalletAddress.shortAddress) / mint \(draft.mintAddress.shortAddress)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.system(.callout, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var approvalControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Approval")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.secondaryText)

            TextField(TransactionApprovalPolicy.requiredMainnetConfirmation, text: $mainnetConfirmation)
                .textFieldStyle(.roundedBorder)

            Toggle("I reviewed the Cloak fixed and variable fee model for withdraw/send paths.", isOn: $feeAcknowledged)
            Toggle("I completed the Shield review and understand this stores local private state.", isOn: $shieldReviewCompleted)
            Toggle("I explicitly approve this real mainnet Cloak deposit.", isOn: $explicitApproval)

            Text("The helper can request scoped transaction/message signatures, but TypeScript never receives the wallet seed or private key.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private var lockedActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Other private actions")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.secondaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach([CloakActionKind.privateTransfer, .partialWithdraw, .privateSwap, .complianceScan]) { action in
                    Button {
                        walletManager.blockCloakAction(action)
                    } label: {
                        Label(action.title, systemImage: "lock")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.gorkhSecondary)
                }
            }
        }
    }

    private var canExecuteDeposit: Bool {
        walletManager.currentCloakDepositDraft != nil
            && walletManager.selectedNetwork == .mainnetBeta
            && mainnetConfirmation == TransactionApprovalPolicy.requiredMainnetConfirmation
            && feeAcknowledged
            && shieldReviewCompleted
            && explicitApproval
            && !walletManager.isBusy
    }
}
