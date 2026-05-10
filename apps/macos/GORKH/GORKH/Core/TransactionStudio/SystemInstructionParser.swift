import Foundation

enum SystemInstructionParser {
    static func parse(accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        guard let discriminator = TransactionInstructionParserFormatting.readUInt32LE(data, offset: 0) else {
            return partial("System instruction", accounts: accounts, dataLength: data.count)
        }

        switch discriminator {
        case 0:
            return parseCreateAccount(accounts: accounts, data: data)
        case 1:
            return parseAssign(accounts: accounts, data: data)
        case 2:
            return parseTransfer(accounts: accounts, data: data)
        case 8:
            return parseAllocate(accounts: accounts, data: data)
        default:
            return partial("Unknown system instruction", accounts: accounts, dataLength: data.count)
        }
    }

    private static func parseTransfer(accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        guard let lamports = TransactionInstructionParserFormatting.readUInt64LE(data, offset: 4) else {
            return partial("System transfer", accounts: accounts, dataLength: data.count)
        }
        let from = TransactionInstructionParserFormatting.account(accounts, 0)
        let to = TransactionInstructionParserFormatting.account(accounts, 1)
        return TransactionParsedInstruction(
            status: .recognized,
            action: "System transfer \(TransactionInstructionParserFormatting.solAmount(lamports: lamports))",
            details: [
                .init(label: "From", value: from ?? "unavailable"),
                .init(label: "To", value: to ?? "unavailable"),
                .init(label: "Lamports", value: "\(lamports)"),
                .init(label: "Amount", value: TransactionInstructionParserFormatting.solAmount(lamports: lamports))
            ],
            riskHints: ["Native SOL transfer"],
            explanationFragment: "This transaction transfers \(TransactionInstructionParserFormatting.solAmount(lamports: lamports)) from \(short(from)) to \(short(to))."
        )
    }

    private static func parseCreateAccount(accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        let lamports = TransactionInstructionParserFormatting.readUInt64LE(data, offset: 4)
        let space = TransactionInstructionParserFormatting.readUInt64LE(data, offset: 12)
        let owner = TransactionInstructionParserFormatting.readPubkey(data, offset: 20)
        let status: TransactionInstructionParseStatus = lamports == nil || space == nil || owner == nil ? .partial : .recognized
        return TransactionParsedInstruction(
            status: status,
            action: "Create account",
            details: [
                .init(label: "Funding account", value: TransactionInstructionParserFormatting.account(accounts, 0) ?? "unavailable"),
                .init(label: "New account", value: TransactionInstructionParserFormatting.account(accounts, 1) ?? "unavailable"),
                .init(label: "Lamports", value: lamports.map(String.init) ?? "unavailable"),
                .init(label: "Space", value: space.map { "\($0) byte(s)" } ?? "unavailable"),
                .init(label: "Owner program", value: owner ?? "unavailable")
            ],
            riskHints: [],
            explanationFragment: "This transaction creates a new account funded by \(short(TransactionInstructionParserFormatting.account(accounts, 0)))."
        )
    }

    private static func parseAssign(accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        let owner = TransactionInstructionParserFormatting.readPubkey(data, offset: 4)
        return TransactionParsedInstruction(
            status: owner == nil ? .partial : .recognized,
            action: "Assign account owner",
            details: [
                .init(label: "Account", value: TransactionInstructionParserFormatting.account(accounts, 0) ?? "unavailable"),
                .init(label: "New owner program", value: owner ?? "unavailable")
            ],
            riskHints: ["Authority change"],
            explanationFragment: "This transaction assigns an account to a different owner program."
        )
    }

    private static func parseAllocate(accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        let space = TransactionInstructionParserFormatting.readUInt64LE(data, offset: 4)
        return TransactionParsedInstruction(
            status: space == nil ? .partial : .recognized,
            action: "Allocate account data",
            details: [
                .init(label: "Account", value: TransactionInstructionParserFormatting.account(accounts, 0) ?? "unavailable"),
                .init(label: "Space", value: space.map { "\($0) byte(s)" } ?? "unavailable")
            ],
            riskHints: [],
            explanationFragment: "This transaction allocates account data space."
        )
    }

    private static func partial(_ action: String, accounts: [DecodedAccountMeta], dataLength: Int) -> TransactionParsedInstruction {
        TransactionParsedInstruction(
            status: .partial,
            action: action,
            details: [
                .init(label: "Accounts", value: "\(accounts.count)"),
                .init(label: "Raw data", value: "\(dataLength) byte(s)")
            ],
            riskHints: [],
            explanationFragment: nil
        )
    }

    private static func short(_ value: String?) -> String {
        TransactionInstructionParserFormatting.short(value ?? "unknown")
    }
}
