import Combine
import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedSection: WalletSection = .overview
    private let autoLockTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            walletLayout(
                showSidebar: proxy.size.width >= 900 && walletManager.selectedProfile != nil,
                showInspector: proxy.size.width >= 1180,
                compact: proxy.size.width < 760
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(autoLockTimer) { now in
            walletManager.enforceAutoLockIfNeeded(now: now)
        }
        .onChange(of: walletManager.selectedWalletID) { _, _ in
            normalizeSelectedSection()
        }
        .onChange(of: appState.requestedWalletSection) { _, section in
            guard let section else {
                return
            }
            if availableSections.contains(section) {
                selectedSection = section
            } else {
                selectedSection = .overview
            }
            appState.requestedWalletSection = nil
        }
    }

    private func walletLayout(showSidebar: Bool, showInspector: Bool, compact: Bool) -> some View {
        HStack(spacing: 0) {
            if showSidebar {
                walletSidebar

                Divider()
                    .overlay(GorkhColors.border)
            }

            VStack(spacing: 0) {
                header(compact: compact)

                if walletManager.selectedProfile != nil {
                    sectionToolbar(compact: compact)
                }

                Divider()
                    .overlay(GorkhColors.border)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if walletManager.profiles.isEmpty {
                            WalletEmptyStateView(content: .noWallet)
                            WalletCreateView()
                            WalletImportView()
                            AddWatchOnlyWalletView()
                        }

                        if walletManager.selectedProfile != nil {
                            selectedSectionView

                            if !showInspector {
                                WalletInspectorView(sectionTitle: selectedSection.title)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        } else {
                            WalletActivityView()
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showInspector {
                Divider()
                    .overlay(GorkhColors.border)

                WalletInspectorView(sectionTitle: selectedSection.title)
                    .frame(width: 310)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var walletSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wallet")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
                .padding(.horizontal, 14)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(availableSections) { section in
                        walletSectionButton(section)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }

            Divider()
                .overlay(GorkhColors.border)

            VStack(alignment: .leading, spacing: 8) {
                Text(walletManager.selectedNetwork.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                    .lineLimit(1)
                Text(walletManager.selectedProfile?.isWatchOnly == true ? "Watch-only wallet" : walletManager.vaultState.title)
                    .font(.caption2)
                    .foregroundStyle(walletManager.selectedProfile?.isWatchOnly == true ? GorkhColors.warning : GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(width: 190)
        .background(GorkhColors.sidebar)
        .accessibilityIdentifier("wallet.section.navigation")
    }

    private func walletSectionButton(_ section: WalletSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.systemImage)
                    .frame(width: 18)
                Text(section.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(selectedSection == section ? GorkhColors.primaryText : GorkhColors.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selectedSection == section ? GorkhColors.panel : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(section.title)
    }

    private func sectionToolbar(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        if selectedSection != .overview {
                            Button {
                                selectedSection = .overview
                            } label: {
                                Label("Back to Overview", systemImage: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        sectionMenu
                    }

                    sectionTitleBlock
                }
            } else {
                HStack(spacing: 10) {
                    if selectedSection != .overview {
                        Button {
                            selectedSection = .overview
                        } label: {
                            Label("Back to Overview", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                    }

                    sectionTitleBlock

                    Spacer()

                    sectionMenu
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private var sectionTitleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selectedSection.title)
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
            Text(selectedSection.subtitle)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sectionMenu: some View {
        Picker("Wallet section", selection: $selectedSection) {
            ForEach(availableSections) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 190)
        .accessibilityIdentifier("wallet.section.navigation")
    }

    private var availableSections: [WalletSection] {
        guard walletManager.selectedProfile?.canSign == false else {
            return WalletSection.productionOrder
        }
        return WalletSection.watchOnlyOrder
    }

    private func header(compact: Bool) -> some View {
        let titleBlock = VStack(alignment: .leading, spacing: 4) {
            Text("Wallet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(GorkhColors.primaryText)
            Text("Own, review, send, protect, and understand your Solana assets.")
                .font(.callout)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }

        let statusChips = HStack(spacing: 8) {
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

        return VStack(alignment: .leading, spacing: 12) {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    titleBlock
                    statusChips
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    titleBlock

                    Spacer(minLength: 12)

                    statusChips
                }
            }

            GorkhPanel {
                VStack(alignment: .leading, spacing: 12) {
                    profileNetworkControls(compact: compact)

                    selectedProfileSummary

                    vaultControls(compact: compact)

                    WalletSecurityStatusStripView()
                }
            }
        }
        .padding(18)
    }

    private func profileNetworkControls(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    profilePicker(compact: true)
                    networkPicker(compact: true)
                }
            } else {
                HStack(spacing: 12) {
                    profilePicker(compact: false)
                    networkPicker(compact: false)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedProfileSummary: some View {
        if let profile = walletManager.selectedProfile {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.label)
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
                Text(profile.publicAddress)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: profile.profileKind.displayName,
                        systemImage: profile.canSign ? "key" : "eye",
                        color: profile.canSign ? GorkhColors.accent : GorkhColors.warning
                    )
                    if profile.profileKind != .watchOnly {
                        GorkhStatusChip(title: profile.walletOrigin.displayName, systemImage: "key", color: GorkhColors.accent)
                    }
                }
                if let derivationPath = profile.derivationPath {
                    Text(derivationPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.secondaryText)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            Text("No wallet is configured on this Mac.")
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private func vaultControls(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    vaultChip
                    walletLockControls
                }
            } else {
                HStack(spacing: 10) {
                    vaultChip
                    Spacer()
                    walletLockControls
                }
            }
        }
    }

    @ViewBuilder
    private var walletLockControls: some View {
        if walletManager.selectedProfile?.canSign == true {
            HStack(spacing: 8) {
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
        } else if walletManager.selectedProfile?.isWatchOnly == true {
            GorkhStatusChip(title: "No signer", systemImage: "eye.slash", color: GorkhColors.warning)
        }
    }

    private func profilePicker(compact: Bool) -> some View {
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
        .frame(maxWidth: compact ? .infinity : 260)
    }

    @ViewBuilder
    private func networkPicker(compact: Bool) -> some View {
        if compact {
            Picker("Network", selection: Binding(
                get: { walletManager.selectedNetwork },
                set: { walletManager.setNetwork($0) }
            )) {
                ForEach(WalletNetwork.allCases) { network in
                    Text(network.displayName).tag(network)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        } else {
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
