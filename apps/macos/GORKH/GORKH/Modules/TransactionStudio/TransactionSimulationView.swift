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
                watchListView
                accountDiffView
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

    private var watchListView: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                if simulation.watchList.accounts.isEmpty {
                    Text("No bounded account watchlist was supplied.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    HStack {
                        Text("\(simulation.watchList.accounts.count)/\(simulation.watchList.maxCount) watched account(s)")
                            .font(.caption)
                            .foregroundStyle(GorkhColors.secondaryText)
                        if simulation.watchList.truncated {
                            GorkhStatusChip(title: "Truncated", systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                        }
                    }
                    ForEach(simulation.watchList.accounts) { account in
                        HStack(alignment: .top) {
                            Text(account.reason)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                                .frame(width: 140, alignment: .leading)
                            Text(account.address)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(account.isWritable ? GorkhColors.warning : GorkhColors.primaryText)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        } label: {
            Text("Account watchlist")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
        }
    }

    private var accountDiffView: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                GorkhStatusChip(title: simulation.accountDiff.status.title, systemImage: "plus.forwardslash.minus", color: simulation.accountDiff.status == .available ? GorkhColors.success : GorkhColors.warning)
                if let reason = simulation.accountDiff.unavailableReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                }
                if simulation.accountDiff.rows.isEmpty {
                    Text("Account diff unavailable from simulation.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ForEach(simulation.accountDiff.rows) { diff in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(diff.address)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(GorkhColors.primaryText)
                                .textSelection(.enabled)
                            Text(diff.status)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            Text("Lamports: \(diff.lamportsBefore.map(String.init) ?? "?") -> \(diff.lamportsAfter.map(String.init) ?? "?")\(diff.lamportsDelta.map { " (\($0 >= 0 ? "+" : "")\($0))" } ?? "")")
                                .font(.caption)
                                .foregroundStyle(GorkhColors.secondaryText)
                            if diff.tokenAmountBefore != nil || diff.tokenAmountAfter != nil {
                                Text("Token amount: \(diff.tokenAmountBefore ?? "?") -> \(diff.tokenAmountAfter ?? "?")\(diff.tokenAmountDelta.map { " (\($0.hasPrefix("-") ? "" : "+")\($0))" } ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            if diff.ownerBefore != diff.ownerAfter {
                                Text("Owner: \(diff.ownerBefore ?? "?") -> \(diff.ownerAfter ?? "?")")
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.warning)
                            }
                        }
                        .padding(8)
                        .background(GorkhColors.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        } label: {
            Text("Account diff")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
        }
    }
}
