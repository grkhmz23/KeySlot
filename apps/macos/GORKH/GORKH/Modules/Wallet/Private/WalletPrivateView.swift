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
                            Text("Shielded balances, deposits, private transfers, and withdrawals powered by Cloak.")
                                .foregroundStyle(GorkhColors.primaryText)
                            Text("Phase 2.2 is architecture only. GORKH will not build, sign, or send Cloak transactions yet.")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.warning)
                        }

                        Spacer()

                        GorkhStatusChip(
                            title: walletManager.cloakAdapterStatus.title,
                            systemImage: "lock.shield",
                            color: GorkhColors.warning
                        )
                    }
                }
            }

            CloakStatusView()
            CloakDepositDraftView()
            CloakFeeModelView()
            CloakShieldReviewPlaceholderView()
            CloakPrivateHistoryPlaceholderView()
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
