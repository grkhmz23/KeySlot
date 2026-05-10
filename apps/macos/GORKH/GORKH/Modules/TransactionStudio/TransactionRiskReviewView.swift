import SwiftUI

struct TransactionRiskReviewView: View {
    let review: TransactionRiskReview

    var body: some View {
        GorkhPanel("Risk Review") {
            VStack(alignment: .leading, spacing: 12) {
                GorkhStatusChip(title: review.level.title, systemImage: "exclamationmark.shield", color: color(for: review.level))
                if review.flags.isEmpty {
                    Text("No deterministic risk flags have been generated yet.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ForEach(review.flags) { flag in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flag.kind.rawValue)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            Text(flag.message)
                                .foregroundStyle(GorkhColors.primaryText)
                        }
                        .padding(10)
                        .background(GorkhColors.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func color(for level: TransactionRiskLevel) -> Color {
        switch level {
        case .low:
            return GorkhColors.accent
        case .medium, .unknown:
            return GorkhColors.warning
        case .high:
            return .red
        }
    }
}
