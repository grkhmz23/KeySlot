import SwiftUI

struct WalletEmptyStateContent: Equatable {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?

    static let noWallet = WalletEmptyStateContent(
        title: "No wallet yet",
        message: "Create, import, or add a watch-only wallet to start tracking balances.",
        systemImage: "wallet.pass",
        actionTitle: "Set up wallet"
    )

    static let walletLocked = WalletEmptyStateContent(
        title: "Wallet locked",
        message: "Unlock before preparing sends or private payment actions. Read-only portfolio data remains visible.",
        systemImage: "lock",
        actionTitle: "Unlock"
    )

    static let noBalance = WalletEmptyStateContent(
        title: "No balance loaded",
        message: "Refresh Portfolio to load SOL, token, and value estimates from the selected RPC network.",
        systemImage: "tray",
        actionTitle: "Refresh"
    )

    static let dataUnavailable = WalletEmptyStateContent(
        title: "Data unavailable",
        message: "The current provider could not return this read-only data. Existing wallet state is unchanged.",
        systemImage: "exclamationmark.triangle",
        actionTitle: nil
    )
}

struct WalletEmptyStateView: View {
    let content: WalletEmptyStateContent
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: content.systemImage)
                    .foregroundStyle(GorkhColors.warning)
                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
            }

            Text(content.message)
                .font(.callout)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle = content.actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "arrow.right")
                }
                .buttonStyle(.keyslotSecondary)
            }
        }
        .padding(14)
        .background(GorkhColors.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(GorkhColors.border)
        }
    }
}
