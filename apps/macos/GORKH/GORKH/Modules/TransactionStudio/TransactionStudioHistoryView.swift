import SwiftUI

struct TransactionStudioHistoryView: View {
    let entries: [TransactionStudioHistoryEntry]
    let clearAction: () -> Void

    var body: some View {
        GorkhPanel("Studio History") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Safe summaries only")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Spacer()
                    Button(action: clearAction) {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.gorkhSecondary)
                    .disabled(entries.isEmpty)
                }
                if entries.isEmpty {
                    Text("No Studio history yet.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                GorkhStatusChip(title: entry.inputKind.title, systemImage: "doc.text", color: GorkhColors.accent)
                                GorkhStatusChip(title: entry.riskLevel.title, systemImage: "exclamationmark.shield", color: entry.riskLevel == .high ? .red : GorkhColors.warning)
                                GorkhStatusChip(title: entry.simulationStatus.title, systemImage: "waveform.path.ecg", color: entry.simulationStatus == .success ? GorkhColors.accent : GorkhColors.warning)
                            }
                            Text(entry.publicReference)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(GorkhColors.secondaryText)
                                .textSelection(.enabled)
                            Text(entry.summary)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.primaryText)
                                .lineLimit(3)
                        }
                        .padding(10)
                        .background(GorkhColors.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
