import Combine
import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var walletManager: WalletManager
    private let autoLockTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    WalletCreateView()
                    WalletImportView()

                    if walletManager.selectedProfile != nil {
                        WalletSecurityView()
                        WalletBalanceView()
                        TokenBalancesView()
                        SendSolView()
                    }

                    AuditLogView()
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()
                .overlay(GorkhColors.border)

            WalletInspectorView()
                .frame(width: 310)
        }
        .onReceive(autoLockTimer) { now in
            walletManager.enforceAutoLockIfNeeded(now: now)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wallet")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("Native Solana signer with explicit review before send.")
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                Spacer()

                GorkhStatusChip(
                    title: walletManager.selectedNetwork.displayName,
                    systemImage: walletManager.selectedNetwork.isMainnet ? "exclamationmark.triangle.fill" : "network",
                    color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent
                )
            }

            GorkhPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        profilePicker
                        networkPicker
                    }

                    if let profile = walletManager.selectedProfile {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.label)
                                .font(.headline)
                                .foregroundStyle(GorkhColors.primaryText)
                            Text(profile.publicAddress)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundStyle(GorkhColors.secondaryText)
                            HStack(spacing: 8) {
                                GorkhStatusChip(title: profile.walletOrigin.displayName, systemImage: "key", color: GorkhColors.accent)
                                if let derivationPath = profile.derivationPath {
                                    Text(derivationPath)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(GorkhColors.secondaryText)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    } else {
                        Text("No wallet is configured on this Mac.")
                            .foregroundStyle(GorkhColors.secondaryText)
                    }

                    HStack {
                        vaultChip
                        Spacer()
                        Button {
                            Task { await walletManager.unlockWallet() }
                        } label: {
                            Label("Unlock", systemImage: "lock.open")
                        }
                        .buttonStyle(.gorkhSecondary)
                        .disabled(walletManager.selectedProfile == nil || walletManager.vaultState == .unlocked)

                        Button {
                            walletManager.lockWallet()
                        } label: {
                            Label("Lock", systemImage: "lock")
                        }
                        .buttonStyle(.gorkhSecondary)
                        .disabled(walletManager.selectedProfile == nil || walletManager.vaultState != .unlocked)
                    }
                }
            }
        }
    }

    private var profilePicker: some View {
        Picker("Wallet", selection: Binding(
            get: { walletManager.selectedWalletID },
            set: { walletManager.selectProfile($0) }
        )) {
            if walletManager.profiles.isEmpty {
                Text("No wallet").tag(Optional<UUID>.none)
            }
            ForEach(walletManager.profiles) { profile in
                Text(profile.label).tag(Optional(profile.id))
            }
        }
        .frame(maxWidth: 260)
    }

    private var networkPicker: some View {
        Picker("Network", selection: Binding(
            get: { walletManager.selectedNetwork },
            set: { walletManager.setNetwork($0) }
        )) {
            ForEach(WalletNetwork.allCases) { network in
                Text(network.displayName).tag(network)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 260)
    }

    private var vaultChip: some View {
        let state = walletManager.vaultState
        let color: Color = {
            switch state {
            case .unlocked:
                return GorkhColors.success
            case .locked:
                return GorkhColors.warning
            case .missing, .error:
                return GorkhColors.danger
            }
        }()

        return GorkhStatusChip(title: state.title, systemImage: state == .unlocked ? "checkmark.seal" : "lock", color: color)
    }
}
