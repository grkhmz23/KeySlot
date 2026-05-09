import SwiftUI

struct CloakDepositDraftView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var amountSOLText = "0.01"

    var body: some View {
        GorkhPanel("Deposit Draft") {
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

                    GorkhStatusChip(title: "Execution locked", systemImage: "lock.fill", color: GorkhColors.warning)
                }

                if let draft = walletManager.currentCloakDepositDraft {
                    draftSummary(draft)
                } else {
                    Text("Prepare a SOL amount to preview Cloak minimums, fixed fee, variable fee, and estimated private net amount.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                lockedActions

                if let response = walletManager.cloakBridgeResponse {
                    Text(response.message)
                        .font(.caption)
                        .foregroundStyle(response.status == .blocked ? GorkhColors.danger : GorkhColors.warning)
                }
            }
        }
    }

    private func draftSummary(_ draft: CloakDepositDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                metric("Gross", value: draft.feeQuote.grossSOLText)
                metric("Fee", value: draft.feeQuote.totalFeeSOLText)
                metric("Private Net", value: draft.feeQuote.netSOLText)
            }

            Text(draft.networkWarning ?? "")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
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

    private var lockedActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Locked actions")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.secondaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(CloakActionKind.allCases) { action in
                    Button {
                        walletManager.blockCloakAction(action)
                    } label: {
                        Label(action.title, systemImage: action == .deposit ? "lock.doc" : "lock")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.gorkhSecondary)
                }
            }
        }
    }
}
