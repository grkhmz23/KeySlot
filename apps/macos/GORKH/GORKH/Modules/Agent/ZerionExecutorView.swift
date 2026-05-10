import SwiftUI

struct ZerionExecutorView: View {
    let snapshot: ZerionStatusSnapshot
    let isRefreshing: Bool
    let refreshAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GorkhPanel("Zerion Executor") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("A2 checks Zerion CLI, API key, wallet, policy, token, and swap command-shape readiness. Only an approved tiny swap can execute.")
                        .foregroundStyle(GorkhColors.secondaryText)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                        row("CLI", snapshot.cliStatus.label, "terminal")
                        row("Executable", snapshot.executablePath ?? "Not found", "folder")
                        row("Node.js", snapshot.nodeVersion.map { "\(snapshot.nodeStatus.label) \($0)" } ?? snapshot.nodeStatus.label, "server.rack")
                        row("API key", snapshot.apiKeyStatus.label, "key")
                        row("Agent token", snapshot.agentTokenStatus.label, "person.badge.key")
                        row("Policies", snapshot.policyStatus.label, "checklist")
                        row("Swap help", snapshot.swapHelpStatus?.rawValue ?? "unchecked", "questionmark.circle")
                        row("Swap shape", snapshot.swapCommandShape.label, "arrow.left.arrow.right")
                        row("Wallets", snapshot.walletCount.map(String.init) ?? "Unknown", "wallet.pass")
                        row("Chains", snapshot.supportedChains.isEmpty ? "Unknown" : snapshot.supportedChains.joined(separator: ", "), "link")
                    }

                    HStack {
                        Button(action: refreshAction) {
                            Label(isRefreshing ? "Checking..." : "Refresh Read-Only Status", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRefreshing)

                        GorkhStatusChip(title: "Tiny swap gated", systemImage: "lock.open.trianglebadge.exclamationmark", color: GorkhColors.warning)
                        GorkhStatusChip(title: "No bridge / send / signing", systemImage: "lock", color: GorkhColors.warning)
                    }
                }
            }

            if snapshot.errors.isEmpty == false {
                GorkhPanel("Status Messages") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(snapshot.errors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(GorkhColors.warning)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("agent.zerion.executor")
    }

    private func row(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(GorkhColors.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(value)
                    .font(.callout)
                    .foregroundStyle(GorkhColors.primaryText)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer()
        }
    }
}
