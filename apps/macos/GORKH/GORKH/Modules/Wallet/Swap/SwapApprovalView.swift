import SwiftUI

struct SwapApprovalView: View {
    let quote: JupiterQuoteSummary?
    let review: SwapTransactionReview?
    let simulation: SimulationResult?
    let approvalState: ApprovalState
    @Binding var mainnetConfirmation: String
    @Binding var completedDevnetSmoke: Bool
    let approveAction: () -> Void
    let canApprove: Bool

    var body: some View {
        GorkhPanel("Swap Approval") {
            if let quote {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: simulation?.status.rawValue ?? "not simulated", systemImage: "waveform.path.ecg", color: simulation?.status == .success ? GorkhColors.success : GorkhColors.warning)
                        GorkhStatusChip(title: approvalStatusTitle, systemImage: "signature", color: approvalColor)
                        GorkhStatusChip(title: "Mainnet real funds", systemImage: "exclamationmark.triangle.fill", color: GorkhColors.warning)
                    }

                    approvalRow("Input mint", quote.inputMint)
                    approvalRow("Output mint", quote.outputMint)
                    approvalRow("Input raw", "\(quote.inAmount)")
                    approvalRow("Expected output raw", "\(quote.outAmount)")
                    approvalRow("Minimum received raw", "\(quote.otherAmountThreshold)")
                    approvalRow("Slippage", "\(quote.slippageBps) bps")
                    approvalRow("Route", quote.routeLabel)
                    approvalRow("Review", review?.canApprove == true ? "passed" : "missing or blocked")
                    approvalRow("Estimated fee", simulation?.estimatedFeeLamports.map { "\($0) lamports" } ?? "Unavailable")

                    Text("Mainnet swaps are irreversible and can permanently move real funds. Verify tokens, route, minimum received, fee payer, programs, and simulation before approving.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)

                    TextField(TransactionApprovalPolicy.requiredMainnetConfirmation, text: $mainnetConfirmation)
                        .textFieldStyle(.roundedBorder)
                    Toggle("I have completed a devnet smoke send for this build.", isOn: $completedDevnetSmoke)
                        .toggleStyle(.checkbox)
                        .foregroundStyle(GorkhColors.warning)

                    if let logs = simulation?.logs, !logs.isEmpty {
                        DisclosureGroup("Simulation logs") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logs.prefix(16), id: \.self) { line in
                                    Text(line)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(GorkhColors.secondaryText)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }

                    Button(action: approveAction) {
                        Label("Approve Mainnet, Authenticate, Sign Locally, and Send", systemImage: "signature")
                    }
                    .buttonStyle(.gorkhPrimary)
                    .disabled(!canApprove)
                }
            } else {
                Text("Quote, build, review, and simulate before approval.")
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }

    private var approvalStatusTitle: String {
        switch approvalState {
        case .idle:
            return "idle"
        case .drafted:
            return "drafted"
        case .simulated:
            return "ready"
        case .approved:
            return "approved"
        case .sending:
            return "sending"
        case .sent:
            return "sent"
        case .failed:
            return "failed"
        }
    }

    private var approvalColor: Color {
        switch approvalState {
        case .simulated, .sent:
            return GorkhColors.success
        case .failed:
            return GorkhColors.danger
        case .idle, .drafted, .approved, .sending:
            return GorkhColors.warning
        }
    }

    private func approvalRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}
