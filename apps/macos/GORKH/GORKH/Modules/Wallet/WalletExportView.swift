import SwiftUI

enum WalletExportKind: String, CaseIterable, Identifiable {
    case recoveryPhrase = "Recovery Phrase"
    case privateKey = "Private Key"
    case encryptedBackup = "Encrypted Backup"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .recoveryPhrase: return "text.word.spacing"
        case .privateKey: return "key"
        case .encryptedBackup: return "lock.doc"
        }
    }
}

struct WalletExportView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedKind: WalletExportKind = .recoveryPhrase
    @State private var vaultExportCode = ""
    @State private var isExporting = false
    @State private var exportedSecret: String?
    @State private var exportedBackup: WalletBackupPayload?
    @State private var showSecret = false
    @State private var secretDisappearTask: Task<Void, Never>?
    @State private var showCopyWarning = false

    private let secretDisplayDuration: Duration = .seconds(60)

    var body: some View {
        GorkhPanel("Wallet Vault Export") {
            VStack(alignment: .leading, spacing: 16) {
                exportKindPicker

                warningSection

                codeInputSection

                if isExporting {
                    ProgressView("Authenticating…")
                }

                exportResultSection

                exportButton
            }
        }
        .onDisappear {
            clearSecretState()
            walletManager.clearExportResults()
        }
    }

    private var exportKindPicker: some View {
        Picker("Export Kind", selection: $selectedKind) {
            ForEach(WalletExportKind.allCases) { kind in
                Label(kind.rawValue, systemImage: kind.systemImage).tag(kind)
            }
        }
        .pickerStyle(.segmented)
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch selectedKind {
            case .recoveryPhrase:
                Text("Anyone with your recovery phrase can control this wallet.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.danger)
            case .privateKey:
                Text("Anyone with this private key can control this account.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.danger)
            case .encryptedBackup:
                Text("The backup file is encrypted with your Vault Export Code. Store the file and the code in separate locations.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }

            Text("The Vault Export Code protects exports inside KeySlot. It cannot prevent use of an already exported phrase or private key elsewhere.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)

            Text("Normal signing uses device authentication. Export requires device authentication plus the Vault Export Code.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private var codeInputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField("Vault Export Code", text: $vaultExportCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            if let result = walletManager.exportResult {
                exportErrorText(for: result)
            }
            if let result = walletManager.backupExportResult {
                backupErrorText(for: result)
            }
        }
    }

    private var exportResultSection: some View {
        Group {
            if showSecret, let secret = exportedSecret {
                VStack(alignment: .leading, spacing: 8) {
                    Text(secret)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(GorkhColors.primaryText)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(GorkhColors.panelElevated)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(GorkhColors.border))
                        .accessibilityLabel("Exported secret displayed")

                    HStack {
                        Button {
                            showCopyWarning = true
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.keyslotSecondary)
                        .alert("Copy Secret", isPresented: $showCopyWarning) {
                            Button("Cancel", role: .cancel) {}
                            Button("Copy Anyway") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(secret, forType: .string)
                            }
                        } message: {
                            Text("Your clipboard may be accessible to other apps. Only copy if you understand the risk.")
                        }

                        Spacer()

                        Text("Auto-hiding in 60s")
                            .font(.caption2)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }
            }

            if let backup = exportedBackup {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Encrypted backup ready")
                        .font(.callout)
                        .foregroundStyle(GorkhColors.success)

                    Button {
                        saveBackupFile(backup)
                    } label: {
                        Label("Save Backup File", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.keyslotPrimary)
                }
            }
        }
    }

    private var exportButton: some View {
        Button {
            clearSecretState()
            isExporting = true
            Task {
                switch selectedKind {
                case .recoveryPhrase:
                    await walletManager.exportRecoveryPhrase(code: vaultExportCode)
                    if case .success(let phrase) = walletManager.exportResult {
                        await MainActor.run {
                            exportedSecret = phrase
                            showSecret = true
                            scheduleSecretHide()
                        }
                    }
                case .privateKey:
                    await walletManager.exportPrivateKey(code: vaultExportCode)
                    if case .success(let key) = walletManager.exportResult {
                        await MainActor.run {
                            exportedSecret = key
                            showSecret = true
                            scheduleSecretHide()
                        }
                    }
                case .encryptedBackup:
                    await walletManager.exportBackup(code: vaultExportCode)
                    if case .success(let payload) = walletManager.backupExportResult {
                        await MainActor.run {
                            exportedBackup = payload
                        }
                    }
                }
                isExporting = false
            }
        } label: {
            Label("Export", systemImage: "lock.open")
        }
        .buttonStyle(.keyslotPrimary)
        .disabled(vaultExportCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isExporting)
    }

    private func exportErrorText(for result: WalletExportResult<String>) -> some View {
        Group {
            switch result {
            case .locked(let remaining):
                Text("Export locked. Try again in \(Int(remaining)) seconds.")
                    .foregroundStyle(GorkhColors.danger)
            case .wrongCode:
                Text("Incorrect Vault Export Code.")
                    .foregroundStyle(GorkhColors.danger)
            case .missingEnvelope:
                Text("This wallet was created before Vault Export Code support was added. Export is unavailable.")
                    .foregroundStyle(GorkhColors.warning)
            case .failed(let message):
                Text(message)
                    .foregroundStyle(GorkhColors.danger)
            case .localAuthFailed:
                Text("Local authentication failed or was cancelled.")
                    .foregroundStyle(GorkhColors.warning)
            case .success:
                EmptyView()
            }
        }
        .font(.caption)
    }

    private func backupErrorText(for result: WalletExportResult<WalletBackupPayload>) -> some View {
        Group {
            switch result {
            case .locked(let remaining):
                Text("Export locked. Try again in \(Int(remaining)) seconds.")
                    .foregroundStyle(GorkhColors.danger)
            case .wrongCode:
                Text("Incorrect Vault Export Code.")
                    .foregroundStyle(GorkhColors.danger)
            case .missingEnvelope:
                Text("This wallet was created before Vault Export Code support was added. Backup export is unavailable.")
                    .foregroundStyle(GorkhColors.warning)
            case .failed(let message):
                Text(message)
                    .foregroundStyle(GorkhColors.danger)
            case .localAuthFailed:
                Text("Local authentication failed or was cancelled.")
                    .foregroundStyle(GorkhColors.warning)
            case .success:
                EmptyView()
            }
        }
        .font(.caption)
    }

    private func scheduleSecretHide() {
        secretDisappearTask?.cancel()
        secretDisappearTask = Task {
            try? await Task.sleep(for: secretDisplayDuration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                clearSecretState()
            }
        }
    }

    private func clearSecretState() {
        secretDisappearTask?.cancel()
        secretDisappearTask = nil
        exportedSecret = nil
        exportedBackup = nil
        showSecret = false
    }

    private func saveBackupFile(_ payload: WalletBackupPayload) {
        do {
            let data = try WalletBackupEncoder.encode(payload)
            let tempProfile = WalletProfile(
                label: payload.walletLabel,
                publicAddress: payload.walletPublicAddress,
                createdAt: payload.createdAt
            )
            let fileName = WalletBackupEncoder.fileName(for: tempProfile)

            let panel = NSSavePanel()
            panel.nameFieldStringValue = fileName
            panel.allowedContentTypes = [.data]

            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url)
            walletManager.statusMessage = "Backup saved to \(url.lastPathComponent)."
        } catch {
            walletManager.statusMessage = "Failed to save backup: \(error.localizedDescription)"
        }
    }
}
