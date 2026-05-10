import Foundation

enum ATAInstructionParser {
    static func parse(accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        let instructionName: String
        if data.isEmpty || data.first == 0 {
            instructionName = "Create associated token account"
        } else if data.first == 1 {
            instructionName = "Create associated token account idempotent"
        } else if data.first == 2 {
            instructionName = "Recover nested associated token account"
        } else {
            instructionName = "Associated token account instruction"
        }

        return TransactionParsedInstruction(
            status: data.count <= 1 ? .recognized : .partial,
            action: instructionName,
            details: [
                .init(label: "Funding account", value: TransactionInstructionParserFormatting.account(accounts, 0) ?? "unavailable"),
                .init(label: "Associated token account", value: TransactionInstructionParserFormatting.account(accounts, 1) ?? "unavailable"),
                .init(label: "Wallet owner", value: TransactionInstructionParserFormatting.account(accounts, 2) ?? "unavailable"),
                .init(label: "Mint", value: TransactionInstructionParserFormatting.account(accounts, 3) ?? "unavailable"),
                .init(label: "Token program", value: TransactionInstructionParserFormatting.account(accounts, 5) ?? "unavailable")
            ],
            riskHints: [],
            explanationFragment: "This transaction creates or checks an associated token account for wallet \(short(TransactionInstructionParserFormatting.account(accounts, 2)))."
        )
    }

    private static func short(_ value: String?) -> String {
        TransactionInstructionParserFormatting.short(value ?? "unknown")
    }
}
