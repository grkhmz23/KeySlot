import Combine
import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedSection: WalletSection = .overview
    private let autoLockTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if walletManager.profiles.isEmpty {
                        WalletEmptyStateView(content: .noWallet)
                        WalletCreateView()
                        WalletImportView()
                        AddWatchOnlyWalletView()
                    }

                    if walletManager.selectedProfile != nil {
                        sectionPicker
                        selectedSectionView
                    } else {
                        WalletActivityView()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()
                .overlay(GorkhColors.border)

            WalletInspectorView(sectionTitle: selectedSection.title)
                .frame(width: 310)
        }
        .onReceive(autoLockTimer) { now in
            walletManager.enforceAutoLockIfNeeded(now: now)
        }
        .onChange(of: walletManager.selectedWalletID) { _, _ in
            normalizeSelectedSection()
        }
    }

    @ViewBuilder
    private var selectedSectionView: some View {
        if walletManager.selectedProfile?.canSign == false,
           [.send, .swap, .privateWallet, .security].contains(selectedSection) {
            WalletOverviewView { selectedSection = $0 }
        } else {
            switch selectedSection {
            case .overview:
                WalletOverviewView { section in
                    selectedSection = section
                }
            case .portfolio:
                WalletPortfolioView()
            case .send:
                WalletReceiveView()
                SendSolView()
                TokenBalancesView()
            case .swap:
                WalletSwapView()
            case .privateWallet:
                WalletPrivateView()
            case .security:
                WalletSecurityView()
            case .activity:
                WalletActivityView()
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Wallet section", selection: $selectedSection) {
            ForEach(availableSections) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    private var availableSections: [WalletSection] {
        guard walletManager.selectedProfile?.canSign == false else {
            return WalletSection.productionOrder
        }
        return WalletSection.watchOnlyOrder
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wallet")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("Own, review, send, protect, and understand your Solana assets.")
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                Spacer()

                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: "RPC Fast",
                        systemImage: walletManager.rpcProviderSecurityStatus.tokenStatus == .present ? "bolt.horizontal" : "key.slash",
                        color: walletManager.rpcProviderSecurityStatus.tokenStatus == .present ? GorkhColors.accent : GorkhColors.warning
                    )
                    GorkhStatusChip(
                        title: walletManager.selectedNetwork.displayName,
                        systemImage: walletManager.selectedNetwork.isMainnet ? "exclamationmark.triangle.fill" : "network",
                        color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent
                    )
                }
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
                                GorkhStatusChip(
                                    title: profile.profileKind.displayName,
                                    systemImage: profile.canSign ? "key" : "eye",
                                    color: profile.canSign ? GorkhColors.accent : GorkhColors.warning
                                )
                                if profile.profileKind != .watchOnly {
                                    GorkhStatusChip(title: profile.walletOrigin.displayName, systemImage: "key", color: GorkhColors.accent)
                                }
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
                        if walletManager.selectedProfile?.canSign == true {
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
                        } else if walletManager.selectedProfile?.isWatchOnly == true {
                            GorkhStatusChip(title: "No signer", systemImage: "eye.slash", color: GorkhColors.warning)
                        }
                    }

                    WalletSecurityStatusStripView()
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
        if walletManager.selectedProfile?.isWatchOnly == true {
            return GorkhStatusChip(title: "Watch-only", systemImage: "eye", color: GorkhColors.warning)
        }
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

    private func normalizeSelectedSection() {
        if !availableSections.contains(selectedSection) {
            selectedSection = .overview
        }
    }
}
