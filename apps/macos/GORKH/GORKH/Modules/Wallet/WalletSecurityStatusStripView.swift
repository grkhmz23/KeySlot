import SwiftUI

struct WalletSecurityStatusStripContent: Equatable {
    let lockTitle: String
    let lockIsHealthy: Bool
    let autoLockTitle: String
    let autoLockIsHealthy: Bool
    let localAuthenticationTitle: String
    let localAuthenticationIsHealthy: Bool
    let backupTitle: String
    let backupIsHealthy: Bool
    let mainnetProtectionTitle: String
    let signingGuardTitle: String
    let agentSignerAccessTitle: String
    let rpcTitle: String
    let rpcIsHealthy: Bool

    static func make(
        profile: WalletProfile?,
        vaultState: WalletVaultState,
        policy: WalletSecurityPolicy,
        backupStatus: WalletBackupStatus?,
        network: WalletNetwork,
        rpcHealth: RPCHealthSnapshot,
        rpcSecurity: RPCProviderSecurityStatus
    ) -> WalletSecurityStatusStripContent {
        let lockHealthy = profile?.canSign == false || vaultState == .unlocked
        let rpcHealthy = rpcSecurity.tokenStatus == .present && [.healthy, .unchecked].contains(rpcHealth.status)
        let backupHealthy = profile?.isWatchOnly == true || backupStatus?.riskStatus == .backedUp
        return WalletSecurityStatusStripContent(
            lockTitle: profile?.canSign == false ? "Watch-only" : vaultState.title,
            lockIsHealthy: lockHealthy,
            autoLockTitle: "Auto-lock \(policy.autoLockTimeout.displayName)",
            autoLockIsHealthy: policy.autoLockTimeout != .never,
            localAuthenticationTitle: policy.requireLocalAuthenticationForSigning ? "Local auth on" : "Local auth off",
            localAuthenticationIsHealthy: policy.requireLocalAuthenticationForSigning,
            backupTitle: backupStatus?.riskStatus.displayName ?? "Backup unknown",
            backupIsHealthy: backupHealthy,
            mainnetProtectionTitle: network.isMainnet ? "Mainnet phrase on" : "Mainnet guard ready",
            signingGuardTitle: "Signing guard active",
            agentSignerAccessTitle: "Agent signer off",
            rpcTitle: "\(rpcHealth.provider.displayName) \(rpcSecurity.tokenStatus.displayName.lowercased())",
            rpcIsHealthy: rpcHealthy
        )
    }
}

struct WalletSecurityStatusStripView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        let content = WalletSecurityStatusStripContent.make(
            profile: walletManager.selectedProfile,
            vaultState: walletManager.vaultState,
            policy: walletManager.securityPolicy,
            backupStatus: walletManager.selectedBackupStatus,
            network: walletManager.selectedNetwork,
            rpcHealth: walletManager.rpcHealthSnapshot,
            rpcSecurity: walletManager.rpcProviderSecurityStatus
        )

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            chip(content.lockTitle, image: content.lockIsHealthy ? "checkmark.seal" : "lock", healthy: content.lockIsHealthy)
            chip(content.autoLockTitle, image: "timer", healthy: content.autoLockIsHealthy)
            chip(content.localAuthenticationTitle, image: "touchid", healthy: content.localAuthenticationIsHealthy)
            chip(content.backupTitle, image: "externaldrive.badge.checkmark", healthy: content.backupIsHealthy)
            chip(content.mainnetProtectionTitle, image: "exclamationmark.triangle", healthy: true)
            chip(content.signingGuardTitle, image: "signature", healthy: true)
            chip(content.agentSignerAccessTitle, image: "person.crop.circle.badge.xmark", healthy: true)
            chip(content.rpcTitle, image: "bolt.horizontal", healthy: content.rpcIsHealthy)
        }
        .accessibilityLabel("Wallet security status")
    }

    private func chip(_ title: String, image: String, healthy: Bool) -> some View {
        GorkhStatusChip(
            title: title,
            systemImage: image,
            color: healthy ? GorkhColors.success : GorkhColors.warning
        )
    }
}
