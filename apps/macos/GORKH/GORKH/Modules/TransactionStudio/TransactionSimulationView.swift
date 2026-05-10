import SwiftUI

struct TransactionSimulationView: View {
    let simulation: TransactionStudioSimulationSummary

    var body: some View {
        GorkhPanel("Simulation") {
            VStack(alignment: .leading, spacing: 12) {
                GorkhStatusChip(title: simulation.status.title, systemImage: "waveform.path.ecg", color: simulation.status == .success ? GorkhColors.accent : GorkhColors.warning)
                if let units = simulation.unitsConsumed {
                    Text("Units consumed: \(units)")
                        .foregroundStyle(GorkhColors.secondaryText)
                }
                Text(simulation.replacementBlockhashUsed ? "Replacement blockhash was used." : "Replacement blockhash was not used.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                if let error = simulation.errorMessage {
                    Text(error)
                        .foregroundStyle(GorkhColors.warning)
                }
                if simulation.logs.isEmpty {
                    Text("No logs available.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(simulation.logs, id: \.self) { log in
                                Text(log)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(GorkhColors.secondaryText)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxHeight: 460)
                }
            }
        }
    }
}
