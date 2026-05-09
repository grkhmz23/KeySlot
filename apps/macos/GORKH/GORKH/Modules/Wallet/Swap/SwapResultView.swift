import SwiftUI

struct SwapResultView: View {
    let signature: String?
    let confirmationStatus: String?
    let explorerURL: URL?
    let balanceDeltaVerification: SwapBalanceDeltaVerification

    var body: some View {
        guard let signature else {
            return AnyView(EmptyView())
        }

        return AnyView(
            GorkhPanel("Swap Result") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signature")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text(signature)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(GorkhColors.primaryText)
                        .textSelection(.enabled)

                    if let confirmationStatus {
                        Text("Confirmation: \(confirmationStatus)")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }

                    if let explorerURL {
                        Link("Open in Solana Explorer", destination: explorerURL)
                            .font(.caption)
                    }

                    Divider()

                    HStack(spacing: 8) {
                        GorkhStatusChip(
                            title: balanceDeltaVerification.status.rawValue,
                            systemImage: verificationIcon,
                            color: verificationColor
                        )
                        Text(balanceDeltaVerification.message)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }

                    if let inputDelta = balanceDeltaVerification.inputDeltaRaw,
                       let outputDelta = balanceDeltaVerification.outputDeltaRaw {
                        Text("Input delta \(inputDelta) raw, output delta \(outputDelta) raw.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }
            }
        )
    }

    private var verificationColor: Color {
        switch balanceDeltaVerification.status {
        case .verified:
            return GorkhColors.success
        case .mismatch:
            return GorkhColors.danger
        case .pending, .unavailable:
            return GorkhColors.warning
        case .notStarted:
            return GorkhColors.secondaryText
        }
    }

    private var verificationIcon: String {
        switch balanceDeltaVerification.status {
        case .verified:
            return "checkmark.seal"
        case .mismatch:
            return "exclamationmark.octagon"
        case .pending:
            return "clock"
        case .unavailable:
            return "questionmark.circle"
        case .notStarted:
            return "minus.circle"
        }
    }
}
