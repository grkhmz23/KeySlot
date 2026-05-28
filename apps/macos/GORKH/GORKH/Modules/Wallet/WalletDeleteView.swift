import SwiftUI

struct WalletDeleteView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var confirmation = ""
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Text("If you have not backed up your recovery phrase, funds may be lost permanently.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.danger)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Type DELETE WALLET", text: $confirmation)
                    .textFieldStyle(.roundedBorder)

                Button {
                    walletManager.deleteSelectedWallet(confirmation: confirmation)
                    confirmation = ""
                    isExpanded = false
                } label: {
                    Label("Delete Local Wallet", systemImage: "trash")
                }
                .buttonStyle(.keyslotSecondary)
                .disabled(walletManager.selectedProfile == nil || confirmation != "DELETE WALLET" || walletManager.isBusy)
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "trash")
                    .foregroundStyle(GorkhColors.danger)
                Text("Delete wallet from this Mac")
                    .foregroundStyle(GorkhColors.primaryText)
            }
        }
    }
}
