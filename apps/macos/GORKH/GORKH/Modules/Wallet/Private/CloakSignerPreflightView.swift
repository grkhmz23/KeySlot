import SwiftUI

struct CloakSignerPreflightView: View {
    @EnvironmentObject private var walletManager: WalletManager

    var body: some View {
        GorkhPanel("Signer Preflight") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: stateTitle,
                        systemImage: stateSystemImage,
                        color: stateColor
                    )
                    GorkhStatusChip(
                        title: "Native signer only",
                        systemImage: "key.horizontal",
                        color: GorkhColors.accent
                    )
                    GorkhStatusChip(
                        title: "No helper signing",
                        systemImage: "terminal.fill",
                        color: GorkhColors.warning
                    )
                }

                if let request = walletManager.currentCloakSignerRequest {
                    requestSummary(request)
                } else {
                    Text("Prepare a Cloak deposit draft to generate a locked signer request summary and review fingerprint.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                if let result = walletManager.cloakSignerPreflightResult {
                    Text(result.message)
                        .font(.caption)
                        .foregroundStyle(result.state == .rejected ? GorkhColors.danger : GorkhColors.secondaryText)

                    ForEach(result.failures, id: \.self) { failure in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.state == .rejected ? "exclamationmark.triangle.fill" : "lock.fill")
                                .foregroundStyle(result.state == .rejected ? GorkhColors.danger : GorkhColors.warning)
                            Text(failure)
                                .font(.caption)
                                .foregroundStyle(result.state == .rejected ? GorkhColors.danger : GorkhColors.warning)
                        }
                    }
                } else {
                    Text("Future Cloak signTransaction/signMessage requests must pass native policy before any signing prompt can appear.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
    }

    private var stateTitle: String {
        walletManager.cloakSignerPreflightResult?.state.title ?? "Signer bridge locked"
    }

    private var stateSystemImage: String {
        walletManager.cloakSignerPreflightResult?.state == .rejected ? "xmark.octagon" : "lock.shield"
    }

    private var stateColor: Color {
        walletManager.cloakSignerPreflightResult?.state == .rejected ? GorkhColors.danger : GorkhColors.warning
    }

    private func requestSummary(_ request: CloakSignerRequestSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.humanReadableSummary)
                .font(.callout)
                .foregroundStyle(GorkhColors.primaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], alignment: .leading, spacing: 8) {
                metric("Request", value: request.requestKind.title)
                metric("Network", value: request.network.displayName)
                metric("Action", value: request.actionKind.title)
                metric("Amount", value: request.amountLamports.map { "\($0) lamports" } ?? "unavailable")
                metric("Wallet", value: request.walletPublicKey.shortAddress)
                metric("Mint", value: request.mintAddress.shortAddress)
                metric("Program", value: request.programID.shortAddress)
                metric("Fingerprint", value: request.draftFingerprint.shortAddress)
            }

            if let purpose = request.expectedTransactionPurpose {
                Text(purpose)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            if let purpose = request.expectedMessagePurpose {
                Text(purpose)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
