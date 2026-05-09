import SwiftUI

struct WalletPrivateView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var didRecordView = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("Private") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shielded SOL deposits and private pay / full withdraw powered by Cloak.")
                                .foregroundStyle(GorkhColors.primaryText)
                            Text("Cloak is mainnet-only. These are real transactions after explicit approval, LocalAuthentication, native signing, and Activity logging.")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.warning)
                        }

                        Spacer()

                        GorkhStatusChip(
                            title: "Cloak MVP guarded",
                            systemImage: "lock.shield",
                            color: GorkhColors.warning
                        )
                    }
                }
            }

            CloakStatusView()
            CloakDepositDraftView()
            CloakWithdrawView()
            CloakFeeModelView()
            CloakSignerPreflightView()
            CloakApprovalRequirementsView()
            CloakShieldReviewPlaceholderView()
            CloakScanStatusView()
            CloakPrivateActivityView()
            CloakComplianceSummaryView()
            CloakSafetyPanelView()
        }
        .onAppear {
            guard !didRecordView else {
                return
            }
            didRecordView = true
            walletManager.recordPrivateTabViewed()
        }
    }
}
