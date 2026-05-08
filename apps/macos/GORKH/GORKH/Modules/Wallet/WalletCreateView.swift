import SwiftUI

struct WalletCreateView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var label = "GORKH Wallet"
    @State private var acknowledged = false

    var body: some View {
        GorkhPanel("Create Wallet") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Label", text: $label)
                    .textFieldStyle(.roundedBorder)

                Toggle("I understand this creates a local keypair without a seed phrase export in Phase 1.", isOn: $acknowledged)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(GorkhColors.secondaryText)

                Button {
                    walletManager.createWallet(label: label)
                    acknowledged = false
                } label: {
                    Label("Create Local Wallet", systemImage: "plus.circle")
                }
                .buttonStyle(.gorkhPrimary)
                .disabled(!acknowledged || walletManager.isBusy)
            }
        }
    }
}
