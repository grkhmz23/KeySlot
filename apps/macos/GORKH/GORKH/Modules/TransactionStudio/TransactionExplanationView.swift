import SwiftUI

struct TransactionExplanationView: View {
    let explanation: TransactionExplanation
    let copyAction: () -> Void
    let sendToAgentAction: () -> Void
    let saveHistoryAction: () -> Void
    let openActivityAction: () -> Void
    let hasSignature: Bool

    var body: some View {
        GorkhPanel("Explanation") {
            VStack(alignment: .leading, spacing: 12) {
                Text(explanation.summary)
                    .foregroundStyle(GorkhColors.primaryText)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(explanation.reviewChecklist, id: \.self) { item in
                        Label(item, systemImage: "checklist")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                    }
                }
                HStack {
                    Button(action: copyAction) {
                        Label("Copy summary", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.gorkhSecondary)
                    Button(action: sendToAgentAction) {
                        Label("Send to Agent", systemImage: "sparkles")
                    }
                    .buttonStyle(.gorkhSecondary)
                    Button(action: saveHistoryAction) {
                        Label("Save history", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.gorkhSecondary)
                    Button(action: openActivityAction) {
                        Label("Open Activity", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.gorkhSecondary)
                    .disabled(!hasSignature)
                }
                Text("Handoffs copy or route findings only. They do not sign, send, or broadcast.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
        }
    }
}
