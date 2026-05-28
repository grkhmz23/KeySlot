import SwiftUI

struct WalletCreateView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var label = "KeySlot Wallet"
    @State private var derivationPath = DerivationPath.defaultSolana
    @State private var recoveryWords: [String] = []
    @State private var savedOffline = false
    @State private var isConfirming = false

    var body: some View {
        GorkhPanel("Create Wallet with Recovery Phrase") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Label", text: $label)
                    .textFieldStyle(.roundedBorder)

                DerivationPathPicker(derivationPath: $derivationPath)

                if recoveryWords.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("KeySlot generates a BIP39 recovery phrase locally, derives the Solana signer locally, and stores only the derived signing seed in the macOS Keychain-backed vault.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        Text("The phrase is shown once. KeySlot never sends it to a backend, assistant, agent, or model.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }

                    Button {
                        recoveryWords = walletManager.generateRecoveryPhrase()
                        savedOffline = false
                        isConfirming = false
                    } label: {
                        Label("Generate Recovery Phrase", systemImage: "text.word.spacing")
                    }
                    .buttonStyle(.keyslotPrimary)
                    .disabled(walletManager.isBusy)
                } else if isConfirming {
                    RecoveryPhraseConfirmationView(words: recoveryWords) {
                        walletManager.createRecoveryWallet(
                            label: label,
                            recoveryWords: recoveryWords,
                            derivationPath: derivationPath
                        )
                        clearRecoveryState()
                    }
                } else {
                    RecoveryPhraseView(words: recoveryWords)

                    Toggle("I wrote this recovery phrase down and understand KeySlot cannot recover it.", isOn: $savedOffline)
                        .toggleStyle(.checkbox)
                        .foregroundStyle(GorkhColors.warning)

                    HStack {
                        Button {
                            isConfirming = true
                        } label: {
                            Label("Continue to Confirmation", systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.keyslotPrimary)
                        .disabled(!savedOffline)

                        Button {
                            clearRecoveryState()
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.keyslotSecondary)
                    }
                }
            }
        }
    }

    private func clearRecoveryState() {
        recoveryWords.removeAll(keepingCapacity: false)
        savedOffline = false
        isConfirming = false
    }
}
