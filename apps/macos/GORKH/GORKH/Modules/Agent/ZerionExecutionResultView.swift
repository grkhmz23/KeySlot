import SwiftUI

struct ZerionExecutionResultView: View {
    let result: ZerionExecutionResult

    var body: some View {
        GorkhPanel("Zerion Execution Result") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    GorkhStatusChip(
                        title: result.status.label,
                        systemImage: result.status == .executed ? "checkmark.seal" : "exclamationmark.triangle",
                        color: result.status == .executed ? GorkhColors.success : GorkhColors.warning
                    )
                    if let chain = result.chain {
                        GorkhStatusChip(title: chain, systemImage: "link", color: GorkhColors.accent)
                    }
                    Spacer()
                }
                Text(result.message)
                    .foregroundStyle(GorkhColors.primaryText)
                    .textSelection(.enabled)
                if let hash = result.transactionHash {
                    detail("Transaction", hash)
                }
                if let explorerURL = result.explorerURL {
                    Link("Open explorer", destination: explorerURL)
                }
            }
        }
        .accessibilityIdentifier("agent.zerion.execution.result")
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
        }
    }
}
