import SwiftUI

struct RPCInfrastructureSettingsView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RPC Infrastructure")
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
                Spacer()
                GorkhStatusChip(
                    title: walletManager.rpcHealthSnapshot.status.displayName,
                    systemImage: statusIcon,
                    color: statusColor
                )
            }

            Text("GORKH uses RPC Fast as the default Solana RPC provider. Tokens are read from local environment variables only.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)

            VStack(alignment: .leading, spacing: 7) {
                row("Provider", walletManager.rpcFastEndpoint.provider.displayName)
                row("Network", walletManager.selectedNetwork.displayName)
                row("HTTP", walletManager.rpcFastEndpoint.safeHTTPDisplay)
                row("WebSocket", walletManager.rpcFastEndpoint.safeWebSocketDisplay)
                row("Token", walletManager.rpcProviderSecurityStatus.tokenStatus.displayName)
                row("Latency", walletManager.rpcHealthSnapshot.latencyMilliseconds.map { "\($0) ms" } ?? "Not checked")
                row("Slot", walletManager.rpcHealthSnapshot.slot.map(String.init) ?? "Unavailable")
                row("Block height", walletManager.rpcHealthSnapshot.blockHeight.map(String.init) ?? "Unavailable")
                row("Version", walletManager.rpcHealthSnapshot.version ?? "Unavailable")
                row("Last checked", walletManager.rpcHealthSnapshot.checkedAt.formatted(date: .abbreviated, time: .standard))
                row("Beam", "Locked for future review")
            }

            if walletManager.rpcProviderSecurityStatus.tokenStatus == .missing {
                Text("RPC Fast token missing. Set \(walletManager.rpcProviderSecurityStatus.tokenEnvironmentNames.joined(separator: " or ")) before using this network.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            }

            if let errorMessage = walletManager.rpcHealthSnapshot.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await walletManager.refreshRPCProviderHealth() }
            } label: {
                Label("Check RPC Health", systemImage: "speedometer")
            }
            .buttonStyle(.gorkhSecondary)
        }
    }

    private var statusIcon: String {
        switch walletManager.rpcHealthSnapshot.status {
        case .healthy:
            return "checkmark.seal"
        case .degraded:
            return "exclamationmark.triangle"
        case .unavailable, .tokenMissing:
            return "xmark.octagon"
        case .unchecked:
            return "clock"
        }
    }

    private var statusColor: Color {
        switch walletManager.rpcHealthSnapshot.status {
        case .healthy:
            return GorkhColors.success
        case .degraded, .tokenMissing, .unchecked:
            return GorkhColors.warning
        case .unavailable:
            return GorkhColors.danger
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.caption)
    }
}
