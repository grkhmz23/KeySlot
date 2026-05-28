import SwiftUI

// MARK: - Vault Export Code Display

struct VaultExportCodeDisplayView: View {
    let code: String
    let onConfirmed: () -> Void

    @State private var savedOffline = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vault Export Code")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            Text("This code protects exports inside KeySlot. You will need it to export your recovery phrase, private key, or encrypted backup.")
                .font(.callout)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(code)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(GorkhColors.accent)
                .padding(12)
                .background(GorkhColors.panelElevated)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(GorkhColors.border))
                .accessibilityLabel("Vault Export Code displayed")

            VStack(alignment: .leading, spacing: 4) {
                Text("KeySlot cannot recover this code.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.danger)
                Text("Store it in a password manager or write it down and keep it offline.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
                Text("The Vault Export Code is not 2FA. It is a local cryptographic secret used only for export and restore.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Toggle("I wrote this Vault Export Code down in a safe place.", isOn: $savedOffline)
                .toggleStyle(.checkbox)
                .foregroundStyle(GorkhColors.warning)

            Button {
                onConfirmed()
            } label: {
                Label("Continue to Confirmation", systemImage: "arrow.right.circle")
            }
            .buttonStyle(.keyslotPrimary)
            .disabled(!savedOffline)
        }
    }
}

// MARK: - Vault Export Code Confirmation

struct VaultExportCodeConfirmationView: View {
    let code: String
    let onConfirmed: () -> Void
    let onCancelled: () -> Void

    @State private var enteredCode = ""
    @State private var attempted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm Vault Export Code")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)

            Text("Enter the Vault Export Code you just saved to confirm you have it.")
                .font(.callout)
                .foregroundStyle(GorkhColors.secondaryText)

            SecureField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $enteredCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            if attempted && !isCorrect {
                Text("The Vault Export Code does not match. Please check your notes and try again.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.danger)
            }

            HStack {
                Button {
                    attempted = true
                    guard isCorrect else {
                        return
                    }
                    onConfirmed()
                } label: {
                    Label("Confirm and Create Wallet", systemImage: "checkmark.seal")
                }
                .buttonStyle(.keyslotPrimary)
                .disabled(enteredCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    onCancelled()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .buttonStyle(.keyslotSecondary)
            }
        }
    }

    private var isCorrect: Bool {
        VaultExportCode.normalize(enteredCode) == VaultExportCode.normalize(code)
    }
}
