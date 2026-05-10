import SwiftUI

struct ShieldReviewDetailView: View {
    let summary: ShieldReviewSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            rows([
                ("Generated", summary.generatedAt.formatted(date: .abbreviated, time: .standard)),
                ("Requirements", summary.approvalRequirements.map(\.title).joined(separator: ", ")),
                ("Handoff", summary.handoff.note)
            ])

            if let fee = summary.simulation.estimatedFeeLamports {
                rows([("Estimated fee", "\(fee) lamports")])
            }
            if let units = summary.simulation.computeUnits {
                rows([("Compute units", "\(units)")])
            }
            if let error = summary.simulation.errorMessage, error.isEmpty == false {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if summary.simulation.logPreview.isEmpty == false {
                DisclosureGroup("Simulation log preview") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(summary.simulation.logPreview, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(GorkhColors.secondaryText)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func rows(_ values: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(values, id: \.0) { title, value in
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                        .frame(width: 110, alignment: .leading)
                    Text(value.isEmpty ? "Unavailable" : value)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(GorkhColors.primaryText)
                        .textSelection(.enabled)
                    Spacer()
                }
            }
        }
    }
}
