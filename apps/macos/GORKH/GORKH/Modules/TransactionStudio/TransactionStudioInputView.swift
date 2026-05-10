import SwiftUI

struct TransactionStudioInputView: View {
    @Binding var inputText: String
    let selectedNetwork: WalletNetwork
    let detectedInput: TransactionStudioInput?
    let status: TransactionStudioStatus
    let statusMessage: String
    let isWorking: Bool
    let decodeAction: () -> Void
    let simulateAction: () -> Void

    var body: some View {
        GorkhPanel("Input") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste a Solana signature, raw transaction, or address to inspect it. Transaction Studio does not sign or broadcast.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                TextEditor(text: $inputText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 160, maxHeight: 220)
                    .scrollContentBackground(.hidden)
                    .background(GorkhColors.background.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("transactionStudio.input")

                HStack {
                    Button {
                        decodeAction()
                    } label: {
                        Label("Decode", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(isWorking || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        simulateAction()
                    } label: {
                        Label("Simulate", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.gorkhSecondary)
                    .disabled(isWorking)
                }

                Divider().overlay(GorkhColors.border)

                HStack(spacing: 8) {
                    GorkhStatusChip(title: status.title, systemImage: isWorking ? "hourglass" : "checkmark.seal", color: status == .failed ? GorkhColors.warning : GorkhColors.accent)
                    GorkhStatusChip(title: selectedNetwork.displayName, systemImage: selectedNetwork.isMainnet ? "exclamationmark.triangle.fill" : "network", color: selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent)
                }

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                if let detectedInput {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Detected")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        Text("\(detectedInput.kind.title) / \(detectedInput.encoding.rawValue)")
                            .font(.callout)
                            .foregroundStyle(GorkhColors.primaryText)
                        Text(detectedInput.safePreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(GorkhColors.secondaryText)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
