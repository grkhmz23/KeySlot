import SwiftUI

struct SwapResultView: View {
    let signature: String?
    let confirmationStatus: String?
    let explorerURL: URL?

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
                }
            }
        )
    }
}
