import SwiftUI

struct WalletImportView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var label = "Imported Wallet"
    @State private var privateKeyText = ""
    @State private var recoveryPhraseText = ""
    @State private var derivationPath = DerivationPath.defaultSolana
    @State private var previewAddress: String?
    @State private var validationMessage: String?

    var body: some View {
        GorkhPanel("Import Wallet") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Label", text: $label)
                    .textFieldStyle(.roundedBorder)

                SecureField("12 or 24-word recovery phrase", text: $recoveryPhraseText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: recoveryPhraseText) {
                        previewAddress = nil
                        validationMessage = nil
                    }

                DerivationPathPicker(derivationPath: $derivationPath)
                    .onChange(of: derivationPath.rawValue) {
                        previewAddress = nil
                        validationMessage = nil
                    }

                HStack {
                    Button {
                        previewRecoveryAddress()
                    } label: {
                        Label("Preview Address", systemImage: "eye")
                    }
                    .buttonStyle(.keyslotSecondary)
                    .disabled(recoveryPhraseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || walletManager.isBusy)

                    Button {
                        walletManager.importMnemonic(
                            label: label,
                            mnemonic: recoveryPhraseText,
                            derivationPath: derivationPath
                        )
                        recoveryPhraseText = ""
                        previewAddress = nil
                        validationMessage = nil
                    } label: {
                        Label("Import Recovery Phrase", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.keyslotPrimary)
                    .disabled(previewAddress == nil || walletManager.isBusy)
                }

                if let previewAddress {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Derived public address")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        Text(previewAddress)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(GorkhColors.primaryText)
                            .textSelection(.enabled)
                    }
                } else if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.danger)
                }

                Text("Recovery phrases are validated and derived locally. KeySlot stores only the derived signing seed in the local vault and clears this form after import.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                Divider()
                    .overlay(GorkhColors.border)

                SecureField("Private key array or base58 private key", text: $privateKeyText)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button {
                        walletManager.importPrivateKey(label: label, privateKeyText: privateKeyText)
                        privateKeyText = ""
                    } label: {
                        Label("Import Private Key", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.keyslotPrimary)
                    .disabled(privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || walletManager.isBusy)

                    Text("Private key material is parsed locally and cleared from the form after import.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
    }

    private func previewRecoveryAddress() {
        do {
            previewAddress = try walletManager.previewMnemonicAddress(
                mnemonic: recoveryPhraseText,
                derivationPath: derivationPath
            )
            validationMessage = nil
        } catch {
            previewAddress = nil
            validationMessage = error.localizedDescription
        }
    }
}
