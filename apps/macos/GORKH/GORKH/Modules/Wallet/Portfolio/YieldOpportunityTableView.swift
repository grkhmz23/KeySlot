import SwiftUI

struct YieldOpportunityTableView: View {
    let opportunities: [YieldOpportunity]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(opportunities) { opportunity in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(opportunity.label)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(GorkhColors.primaryText)
                            Text("\(opportunity.sourceKind.title) / \(opportunity.sourceEndpoint)")
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        YieldRiskBadgeView(level: opportunity.riskLevel)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 6) {
                        metric("Held", opportunity.isHeld ? (opportunity.heldAmount ?? "yes") : "No")
                        metric(opportunity.rate.kind.title, rateText(opportunity.rate))
                        metric("Value", opportunity.estimatedUSD?.portfolioCurrencyText ?? "Unavailable")
                        metric("TVL", opportunity.tvlUSD?.portfolioCurrencyText ?? "Unavailable")
                        metric("Status", opportunity.status.title)
                    }

                    if let reason = opportunity.unavailableReason ?? opportunity.rate.unavailableReason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(GorkhColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(8)
                .background(GorkhColors.panelElevated.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(GorkhColors.secondaryText)
            Text(value)
                .font(.caption)
                .foregroundStyle(GorkhColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rateText(_ rate: YieldRate) -> String {
        guard let value = rate.value else {
            return "Unavailable"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "Unavailable"
    }
}
