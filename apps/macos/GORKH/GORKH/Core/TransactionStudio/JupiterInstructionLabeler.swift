import Foundation

enum JupiterInstructionLabeler {
    static func parse(programLabel: String, accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        TransactionParsedInstruction(
            status: .partial,
            action: "Jupiter route instruction",
            details: [
                .init(label: "Program", value: programLabel),
                .init(label: "Accounts", value: "\(accounts.count)"),
                .init(label: "Raw data", value: "\(data.count) byte(s)")
            ],
            riskHints: ["DeFi aggregator route", "Token movement may occur"],
            explanationFragment: "This transaction appears to route through Jupiter. Verify route, token movement, simulation logs, and destination-module review before approval."
        )
    }
}
