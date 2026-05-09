import SwiftUI

struct AddWatchOnlyWalletView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var label = ""
    @State private var publicAddress = ""
    @State private var tag = ""

    private var trimmedAddress: String {
        publicAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        SolanaAddressValidator.isValidAddress(trimmedAddress)
    }

    var body: some View {
        GorkhPanel("Add Watch-only Wallet") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Watch-only wallets track public balances only. They cannot unlock, sign, send, or approve transactions.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                HStack(alignment: .top, spacing: 10) {
                    TextField("Label", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)

                    TextField("Public Solana address", text: $publicAddress)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    TextField("Tag", text: $tag)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)

                    Button {
                        walletManager.addWatchOnlyWallet(label: label, publicAddress: publicAddress, tag: tag)
                        if canAdd {
                            label = ""
                            publicAddress = ""
                            tag = ""
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(!canAdd)
                }

                if !publicAddress.isEmpty && !canAdd {
                    Text("Enter a valid Solana public address.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
            }
        }
    }
}
