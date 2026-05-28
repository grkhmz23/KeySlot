import SwiftUI

enum WalletCreateStep: Equatable {
    case generatePhrase
    case displayPhrase(address: String)
    case displayExportCode(address: String, code: String)
    case confirmExportCode(address: String, code: String)
    case confirmPhrase(words: [String], address: String, code: String)
}

struct WalletCreateView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var label = "KeySlot Wallet"
    @State private var derivationPath = DerivationPath.defaultSolana
    @State private var recoveryWords: [String] = []
    @State private var vaultExportCode = ""
    @State private var step: WalletCreateStep = .generatePhrase

    var body: some View {
        GorkhPanel("Create Wallet with Recovery Phrase") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Label", text: $label)
                    .textFieldStyle(.roundedBorder)

                DerivationPathPicker(derivationPath: $derivationPath)

                switch step {
                case .generatePhrase:
                    generatePhraseSection
                case .displayPhrase(let address):
                    displayPhraseSection(address: address)
                case .displayExportCode(let address, let code):
                    VaultExportCodeDisplayView(code: code) {
                        step = .confirmExportCode(address: address, code: code)
                    }
                case .confirmExportCode(let address, let code):
                    VaultExportCodeConfirmationView(
                        code: code,
                        onConfirmed: {
                            step = .confirmPhrase(words: recoveryWords, address: address, code: code)
                        },
                        onCancelled: {
                            resetState()
                        }
                    )
                case .confirmPhrase(let words, let address, let code):
                    RecoveryPhraseConfirmationView(words: words) {
                        walletManager.createRecoveryWallet(
                            label: label,
                            recoveryWords: words,
                            derivationPath: derivationPath,
                            vaultExportCode: code
                        )
                        resetState()
                    }
                }
            }
        }
    }

    private var generatePhraseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KeySlot generates a 24-word BIP39 recovery phrase locally, derives the Solana signer locally, and stores only the derived signing seed in the macOS Keychain-backed vault.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text("The phrase is shown once. KeySlot never sends it to a backend, assistant, agent, or model.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)

            Button {
                recoveryWords = walletManager.generateRecoveryPhrase()
                guard !recoveryWords.isEmpty else { return }
                do {
                    let address = try walletManager.previewMnemonicAddress(
                        mnemonic: recoveryWords.joined(separator: " "),
                        derivationPath: derivationPath
                    )
                    vaultExportCode = VaultExportCode.generate()
                    step = .displayPhrase(address: address)
                } catch {
                    recoveryWords.removeAll(keepingCapacity: false)
                }
            } label: {
                Label("Generate Recovery Phrase", systemImage: "text.word.spacing")
            }
            .buttonStyle(.keyslotPrimary)
            .disabled(walletManager.isBusy)
        }
    }

    private func displayPhraseSection(address: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Derived Address")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(address)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(GorkhColors.primaryText)
                    .textSelection(.enabled)
            }
            .padding(8)
            .background(GorkhColors.panelElevated)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(GorkhColors.border))

            RecoveryPhraseView(words: recoveryWords)

            Text("Default Solana derivation path: \(DerivationPath.defaultSolana.rawValue)")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)

            HStack {
                Button {
                    step = .displayExportCode(address: address, code: vaultExportCode)
                } label: {
                    Label("I wrote this down — Continue", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.keyslotPrimary)

                Button {
                    resetState()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .buttonStyle(.keyslotSecondary)
            }
        }
    }

    private func resetState() {
        recoveryWords.removeAll(keepingCapacity: false)
        vaultExportCode = ""
        step = .generatePhrase
    }
}
