import SwiftUI

struct SecuritySettingsView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Security") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-lock")
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Picker("Timeout", selection: Binding(
                        get: { walletManager.securityPolicy.autoLockTimeout },
                        set: { walletManager.updateAutoLockTimeout($0) }
                    )) {
                        ForEach(WalletAutoLockTimeout.allCases) { timeout in
                            Text(timeout.displayName).tag(timeout)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let warning = walletManager.securityPolicy.autoLockTimeout.warning {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                    }

                    Toggle("Lock when app becomes inactive", isOn: Binding(
                        get: { walletManager.securityPolicy.lockWhenAppInactive },
                        set: { walletManager.updateLockWhenAppInactive($0) }
                    ))
                    .toggleStyle(.checkbox)
                }

                Divider().overlay(GorkhColors.border)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Authentication")
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text(walletManager.authenticationStatusMessage)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Toggle("Require local authentication to unlock", isOn: Binding(
                        get: { walletManager.securityPolicy.requireLocalAuthenticationForUnlock },
                        set: { walletManager.updateRequireLocalAuthenticationForUnlock($0) }
                    ))
                    .toggleStyle(.checkbox)
                    Toggle("Require local authentication before signing", isOn: Binding(
                        get: { walletManager.securityPolicy.requireLocalAuthenticationForSigning },
                        set: { walletManager.updateRequireLocalAuthenticationForSigning($0) }
                    ))
                    .toggleStyle(.checkbox)
                }

                Divider().overlay(GorkhColors.border)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mainnet Gate")
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("Mainnet sends require simulation, explicit approval, the exact confirmation phrase, an unlocked signer, and local authentication where enabled.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                Divider().overlay(GorkhColors.border)

                RPCInfrastructureSettingsView()

                Divider().overlay(GorkhColors.border)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Secret Storage")
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("Secrets are stored in macOS Keychain. Metadata and security preferences are stored locally.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("GORKH does not send seed phrases, private keys, wallet JSON, or signing seeds to a backend, Assistant, Context, LLM, or Agent. Agent signer access is not implemented.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                if let backupStatus = walletManager.selectedBackupStatus {
                    Divider().overlay(GorkhColors.border)
                    WalletBackupView(status: backupStatus)
                }
            }
        }
    }
}
