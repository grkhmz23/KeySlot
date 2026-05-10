import SwiftUI

struct AgentIntentCardView: View {
    let classification: AgentIntentClassification

    var body: some View {
        GorkhPanel("Intent") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    GorkhStatusChip(title: classification.intentType.title, systemImage: "scope", color: color)
                    Spacer()
                    Text("\(Int(classification.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }

                detail("Lane inputs", inputSummary)

                if classification.missingFields.isEmpty == false {
                    detail("Needs", classification.missingFields.joined(separator: ", "))
                }

                if classification.riskFlags.isEmpty == false {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(classification.riskFlags) { flag in
                            Label(flag.label, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("agent.intent.card")
    }

    private var color: Color {
        switch classification.intentType {
        case .unsafe, .unsupported:
            return GorkhColors.danger
        case .portfolioSummary, .riskSummary, .yieldSearch, .lpPositionReview, .pnlSummary, .recentActivitySummary:
            return GorkhColors.accent
        default:
            return GorkhColors.warning
        }
    }

    private var inputSummary: String {
        [
            classification.amount.map { NSDecimalNumber(decimal: $0).stringValue },
            classification.sourceAsset,
            classification.targetAsset.map { "to \($0)" },
            classification.chain,
            classification.recipient.map { "recipient \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(GorkhColors.secondaryText)
            Spacer()
            Text(value.isEmpty ? "Unavailable" : value)
                .foregroundStyle(GorkhColors.primaryText)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
