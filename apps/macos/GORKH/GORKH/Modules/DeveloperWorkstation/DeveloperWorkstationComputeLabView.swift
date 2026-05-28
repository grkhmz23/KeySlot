import SwiftUI

struct DeveloperWorkstationComputeLabView: View {
    @Binding var computeInstructionName: String
    let computeMeasurements: [WorkstationComputeMeasurement]
    let computeBaselines: [WorkstationComputeBaseline]
    let computeRegressionMessage: String
    let transactionDebugReport: TransactionDebugReport?
    let latestTestRun: TestRunEvidence?
    let onStoreFromTransactionDebugger: () -> Void
    let onStoreFromLatestTest: () -> Void
    let onSelectBaseline: (WorkstationComputeMeasurement) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GorkhPanel("Compute Lab") {
                Text("Compute Lab accepts raw transaction fixtures or Transaction Studio handoffs and runs simulation only. No signing or broadcast is available.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                let estimate = WorkstationComputeEstimator.summarize(simulation: .notRun)
                DeveloperWorkstationKeyValueRow(key: "Status", value: estimate.status.rawValue)
                DeveloperWorkstationKeyValueRow(key: "Per-instruction estimate", value: estimate.perInstructionAvailable ? "Available" : "Unavailable")
                DeveloperWorkstationKeyValueRow(key: "Regression source", value: "Use real Compute Lab simulation logs, Transaction Debugger logs, or Test Workbench output.")
            }
            DeveloperWorkstationComputeRegressionPanel(
                computeInstructionName: $computeInstructionName,
                computeMeasurements: computeMeasurements,
                computeBaselines: computeBaselines,
                computeRegressionMessage: computeRegressionMessage,
                transactionDebugReport: transactionDebugReport,
                latestTestRun: latestTestRun,
                includeActions: true,
                onStoreFromTransactionDebugger: onStoreFromTransactionDebugger,
                onStoreFromLatestTest: onStoreFromLatestTest,
                onSelectBaseline: onSelectBaseline
            )
        }
    }
}

struct DeveloperWorkstationComputeRegressionPanel: View {
    @Binding var computeInstructionName: String
    let computeMeasurements: [WorkstationComputeMeasurement]
    let computeBaselines: [WorkstationComputeBaseline]
    let computeRegressionMessage: String
    let transactionDebugReport: TransactionDebugReport?
    let latestTestRun: TestRunEvidence?
    let includeActions: Bool
    let onStoreFromTransactionDebugger: () -> Void
    let onStoreFromLatestTest: () -> Void
    let onSelectBaseline: (WorkstationComputeMeasurement) -> Void

    var body: some View {
        let rows = ComputeRegressionService.rows(measurements: computeMeasurements, baselines: computeBaselines)
        GorkhPanel("Compute Regression") {
            Text("Compute Regression uses real available logs/measurements only. No logs means no measurement. Per-instruction compute is unavailable unless logs expose enough detail.")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                DeveloperWorkstationMetricCard(title: "Measurements", value: "\(computeMeasurements.count)", detail: computeMeasurements.first.map { "\($0.computeUnits) CU from \($0.source.title)" } ?? "No stored logs yet.")
                DeveloperWorkstationMetricCard(title: "Baselines", value: "\(computeBaselines.count)", detail: computeBaselines.first.map { "\($0.computeUnits) CU for \($0.instructionName)" } ?? "Select from real measurements.")
                DeveloperWorkstationMetricCard(title: "Latest status", value: rows.first?.status.title ?? "Unavailable", detail: rows.first?.delta.map { "Delta \($0) CU" } ?? "No comparison.")
            }
            if includeActions {
                DeveloperWorkstationLabeledTextField(label: "Instruction label", text: $computeInstructionName, prompt: "initialize, swap, test-output")
                HStack {
                    Button("Store From Transaction Debugger Logs", action: onStoreFromTransactionDebugger)
                        .buttonStyle(.bordered)
                        .disabled(transactionDebugReport == nil)
                    Button("Store From Latest Test Output", action: onStoreFromLatestTest)
                        .buttonStyle(.bordered)
                        .disabled(latestTestRun == nil)
                }
                Text(computeRegressionMessage)
                    .font(.caption)
                    .foregroundStyle(computeRegressionMessage.lowercased().contains("no compute") || computeRegressionMessage.lowercased().contains("failed") ? GorkhColors.warning : GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if rows.isEmpty {
                Text("No compute measurements stored. Run a real simulation/debug/test flow first, then store measurements from its logs.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.warning)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            WorkstationStatusChip(
                                title: row.status.title,
                                systemImage: row.status == .regressed ? "exclamationmark.triangle" : "chart.line.uptrend.xyaxis",
                                color: row.status == .regressed ? GorkhColors.warning : GorkhColors.success
                            )
                            Text(row.instructionName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GorkhColors.primaryText)
                            Spacer()
                            Button("Use Latest As Baseline") {
                                onSelectBaseline(row.latest)
                            }
                            .buttonStyle(.bordered)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                            DeveloperWorkstationKeyValueRow(key: "Latest CU", value: "\(row.latest.computeUnits)")
                            DeveloperWorkstationKeyValueRow(key: "Baseline CU", value: row.baseline.map { "\($0.computeUnits)" } ?? "Unavailable")
                            DeveloperWorkstationKeyValueRow(key: "Delta", value: row.delta.map { "\($0)" } ?? "Unavailable")
                            DeveloperWorkstationKeyValueRow(key: "Source", value: row.latest.source.title)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider().overlay(GorkhColors.border)
                }
            }
        }
    }
}
