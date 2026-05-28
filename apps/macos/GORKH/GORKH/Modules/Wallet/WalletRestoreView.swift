import SwiftUI

struct WalletRestoreView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var vaultExportCode = ""
    @State private var isRestoring = false
    @State private var selectedFileURL: URL?
    @State private var showFilePicker = false

    var body: some View {
        GorkhPanel("Restore Encrypted Backup") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Restore a wallet from an encrypted .keyslotwallet backup file.")
                    .font(.callout)
                    .foregroundStyle(GorkhColors.secondaryText)

                HStack {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label(selectedFileURL == nil ? "Select Backup File" : "Change File", systemImage: "doc")
                    }
                    .buttonStyle(.keyslotSecondary)

                    if let url = selectedFileURL {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.primaryText)
                            .lineLimit(1)
                    }
                }

                SecureField("Vault Export Code", text: $vaultExportCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                if let result = walletManager.backupRestoreResult {
                    restoreResultText(for: result)
                }

                Button {
                    performRestore()
                } label: {
                    Label("Restore Wallet", systemImage: "lock.open")
                }
                .buttonStyle(.keyslotPrimary)
                .disabled(selectedFileURL == nil || vaultExportCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRestoring)

                if isRestoring {
                    ProgressView("Restoring…")
                }
            }
        }
        .onDisappear {
            walletManager.clearExportResults()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedFileURL = urls.first
            case .failure:
                selectedFileURL = nil
            }
        }
    }

    private func restoreResultText(for result: WalletBackupRestoreResult) -> some View {
        Group {
            switch result {
            case .success:
                Text("Wallet restored successfully.")
                    .foregroundStyle(GorkhColors.success)
            case .wrongCode:
                Text("Incorrect Vault Export Code.")
                    .foregroundStyle(GorkhColors.danger)
            case .locked(let remaining):
                Text("Restore locked. Try again in \(Int(remaining)) seconds.")
                    .foregroundStyle(GorkhColors.danger)
            case .failed(let message):
                Text(message)
                    .foregroundStyle(GorkhColors.danger)
            }
        }
        .font(.caption)
    }

    private func performRestore() {
        guard let url = selectedFileURL else { return }
        isRestoring = true
        Task {
            do {
                let data = try Data(contentsOf: url)
                let payload = try WalletBackupEncoder.decode(data)
                await MainActor.run {
                    walletManager.restoreBackup(payload: payload, code: vaultExportCode)
                    isRestoring = false
                }
            } catch {
                await MainActor.run {
                    walletManager.backupRestoreResult = .failed(error.localizedDescription)
                    isRestoring = false
                }
            }
        }
    }
}
