import SwiftUI

struct TransactionInstructionTimelineView: View {
    let decoded: DecodedTransaction?
    let addressSummary: TransactionStudioAddressSummary?

    var body: some View {
        GorkhPanel("Decode Timeline") {
            if let addressSummary {
                addressView(addressSummary)
            } else if let decoded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        metadata(decoded)
                        ForEach(decoded.instructions) { instruction in
                            instructionRow(instruction)
                        }
                    }
                }
                .frame(maxHeight: 540)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing decoded yet.")
                .font(.headline)
                .foregroundStyle(GorkhColors.primaryText)
            Text("Paste a Solana signature, raw transaction, or address. Unknown instructions are shown honestly without fake decoding.")
                .foregroundStyle(GorkhColors.secondaryText)
        }
    }

    private func metadata(_ decoded: DecodedTransaction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                GorkhStatusChip(title: decoded.transactionVersion, systemImage: "doc.text", color: GorkhColors.accent)
                GorkhStatusChip(title: "\(decoded.instructions.count) instruction(s)", systemImage: "list.bullet", color: GorkhColors.accent)
                if decoded.addressLookupTables.isEmpty == false {
                    GorkhStatusChip(title: "\(decoded.addressLookupTables.count) ALT", systemImage: "tablecells", color: GorkhColors.warning)
                }
            }
            Text("Fee payer: \(decoded.feePayer ?? "unknown")")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
            Text("Recent blockhash: \(decoded.recentBlockhash)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
        }
    }

    private func instructionRow(_ instruction: DecodedInstruction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(instruction.index)")
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
                GorkhStatusChip(title: instruction.programLabel, systemImage: "cpu", color: instruction.programLabel == "Unknown Program" ? GorkhColors.warning : GorkhColors.accent)
                Spacer()
                Text("\(instruction.accounts.count) account(s), \(instruction.dataLength) byte(s)")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            Text(instruction.decodedAction)
                .foregroundStyle(GorkhColors.primaryText)
            Text(instruction.programID)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
            if instruction.riskHints.isEmpty == false {
                HStack {
                    ForEach(instruction.riskHints, id: \.self) { hint in
                        GorkhStatusChip(title: hint, systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                    }
                }
            }
        }
        .padding(12)
        .background(GorkhColors.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func addressView(_ summary: TransactionStudioAddressSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.address)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(GorkhColors.primaryText)
                .textSelection(.enabled)
            HStack {
                GorkhStatusChip(title: summary.ownerLabel ?? "Unknown owner", systemImage: "person.crop.square", color: GorkhColors.accent)
                if summary.executable == true {
                    GorkhStatusChip(title: "Executable", systemImage: "exclamationmark.triangle", color: GorkhColors.warning)
                }
            }
            Text("Lamports: \(summary.lamports.map(String.init) ?? "unknown")")
                .foregroundStyle(GorkhColors.secondaryText)
            Text("Data length: \(summary.dataLength.map(String.init) ?? "unknown")")
                .foregroundStyle(GorkhColors.secondaryText)
            if let tokenAccountSummary = summary.tokenAccountSummary {
                Text(tokenAccountSummary)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            if let warning = summary.warning {
                Text(warning)
                    .foregroundStyle(GorkhColors.warning)
            }
        }
    }
}
