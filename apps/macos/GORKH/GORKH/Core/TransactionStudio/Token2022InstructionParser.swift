import Foundation

enum Token2022InstructionParser {
    static func parse(accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        var parsed = SPLTokenInstructionParser.parse(accounts: accounts, data: data, tokenProgramLabel: "Token-2022")
        var hints = parsed.riskHints
        hints.append("Token-2022 extensions may affect transfers")
        var details = parsed.details
        details.append(.init(label: "Extension data", value: "Not fetched by Transaction Studio v0.1"))
        parsed = TransactionParsedInstruction(
            status: parsed.status,
            action: parsed.action,
            details: details,
            riskHints: hints,
            explanationFragment: "\(parsed.explanationFragment ?? "This transaction uses Token-2022."). Extension data is not fetched here, so transfer hooks or transfer fees may still apply."
        )
        return parsed
    }
}
