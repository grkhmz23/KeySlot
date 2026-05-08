import SwiftUI

struct WalletImportView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var label = "Imported Wallet"
    @State private var privateKeyText = ""
    @State private var mnemonicText = ""

    var body: some View {
        GorkhPanel("Import Wallet") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Label", text: $label)
                    .textFieldStyle(.roundedBorder)

                SecureField("Private key array or base58 private key", text: $privateKeyText)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button {
                        walletManager.importPrivateKey(label: label, privateKeyText: privateKeyText)
                        privateKeyText = ""
                    } label: {
                        Label("Import Private Key", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || walletManager.isBusy)

                    Text("Private key material is parsed locally and cleared from the form after import.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                Divider()
                    .overlay(GorkhColors.border)

                SecureField("Seed phrase import deferred", text: $mnemonicText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)

                Button {
                    walletManager.importMnemonic(label: label, mnemonic: mnemonicText)
                    mnemonicText = ""
                } label: {
                    Label("Import Seed Phrase", systemImage: "text.word.spacing")
                }
                .buttonStyle(.gorkhSecondary)
                .disabled(true)

                Text("Mnemonic import requires audited BIP39 and Solana derivation support. It is not faked in this phase.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }
}
