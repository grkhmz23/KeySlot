import AppKit
import SwiftUI

struct WalletReceiveView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var amount = ""
    @State private var note = ""
    @State private var copiedMessage: String?
    private let fieldColumns = [GridItem(.adaptive(minimum: 180), spacing: 8)]

    var body: some View {
        GorkhPanel("Receive") {
            if let profile = walletManager.selectedProfile {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: walletManager.selectedNetwork.displayName, systemImage: "network", color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent)
                        GorkhStatusChip(title: profile.isWatchOnly ? "Watch-only address" : "Public address", systemImage: "qrcode", color: GorkhColors.accent)
                        if walletManager.selectedNetwork == .mainnetBeta {
                            GorkhStatusChip(title: "Mainnet", systemImage: "exclamationmark.triangle.fill", color: GorkhColors.warning)
                        }
                    }

                    Text(profile.publicAddress)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(GorkhColors.primaryText)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    LazyVGrid(columns: fieldColumns, alignment: .leading, spacing: 8) {
                        TextField("Optional amount", text: $amount)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Optional receive amount")
                        TextField("Optional note", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Optional receive note")
                    }

                    HStack(spacing: 8) {
                        Button {
                            copy(profile.publicAddress, message: "Address copied")
                        } label: {
                            Label("Copy Address", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.gorkhPrimary)
                        .accessibilityLabel("Copy receive address")

                        Button {
                            copy(paymentNote(address: profile.publicAddress), message: "Payment note copied")
                        } label: {
                            Label("Copy Note", systemImage: "text.quote")
                        }
                        .buttonStyle(.gorkhSecondary)
                        .accessibilityLabel("Copy receive payment note")
                    }

                    if walletManager.selectedNetwork == .mainnetBeta {
                        Text("For PUSD, use Solana mainnet and the Palm USD mint \(PUSDConstants.mintAddress.shortAddress). This panel only shares your public address.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    } else {
                        Text("This is a public receive address for the selected network. Never share recovery phrases or private keys.")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }

                    if let copiedMessage {
                        Text(copiedMessage)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.success)
                    }
                }
            } else {
                WalletEmptyStateView(content: .noWallet)
            }
        }
        .accessibilityIdentifier("wallet.receive")
    }

    private func paymentNote(address: String) -> String {
        var parts = [
            "GORKH receive address: \(address)",
            "Network: \(walletManager.selectedNetwork.displayName)"
        ]
        if !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Amount: \(amount)")
        }
        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Note: \(note)")
        }
        return parts.joined(separator: "\n")
    }

    private func copy(_ value: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedMessage = message
    }
}
