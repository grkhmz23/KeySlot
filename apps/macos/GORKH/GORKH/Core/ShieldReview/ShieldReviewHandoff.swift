import Foundation

enum ShieldReviewHandoffBuilder {
    static func safeSummary(for summary: ShieldReviewSummary) -> String {
        var lines = [
            "Shield Review handoff.",
            "Title: \(summary.title)",
            "Status: \(summary.status.title)",
            "Risk: \(summary.riskLevel.title)",
            "Simulation: \(summary.simulation.status.title)",
            "Programs: \(summary.programLabels.isEmpty ? "Unavailable" : summary.programLabels.joined(separator: ", "))",
            "Signers: \(summary.signerCount)",
            "Writable accounts: \(summary.writableCount)",
            "Unknown instructions: \(summary.unknownInstructionCount)"
        ]
        if summary.parsedActions.isEmpty == false {
            lines.append("Actions: \(summary.parsedActions.map { $0.label }.joined(separator: ", "))")
        }
        if summary.riskFlags.isEmpty == false {
            lines.append("Risk flags: \(summary.riskFlags.map(\.message).joined(separator: " | "))")
        }
        lines.append("No raw transaction payload is included or persisted.")
        lines.append("Transaction Studio review is read-only and cannot sign or broadcast.")
        return lines.joined(separator: "\n")
    }
}
