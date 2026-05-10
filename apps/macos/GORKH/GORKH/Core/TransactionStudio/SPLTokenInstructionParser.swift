import Foundation

enum SPLTokenInstructionParser {
    static func parse(accounts: [DecodedAccountMeta], data: Data, tokenProgramLabel: String) -> TransactionParsedInstruction {
        guard let discriminator = data.first else {
            return partial("\(tokenProgramLabel) instruction", accounts: accounts, dataLength: data.count)
        }

        switch discriminator {
        case 1:
            return parseInitializeAccount(accounts: accounts, tokenProgramLabel: tokenProgramLabel)
        case 3:
            return parseTransfer(accounts: accounts, data: data, checked: false, tokenProgramLabel: tokenProgramLabel)
        case 4:
            return parseApprove(accounts: accounts, data: data, checked: false, tokenProgramLabel: tokenProgramLabel)
        case 5:
            return parseRevoke(accounts: accounts, tokenProgramLabel: tokenProgramLabel)
        case 6:
            return parseSetAuthority(accounts: accounts, data: data, tokenProgramLabel: tokenProgramLabel)
        case 9:
            return parseCloseAccount(accounts: accounts, tokenProgramLabel: tokenProgramLabel)
        case 12:
            return parseTransfer(accounts: accounts, data: data, checked: true, tokenProgramLabel: tokenProgramLabel)
        case 13:
            return parseApprove(accounts: accounts, data: data, checked: true, tokenProgramLabel: tokenProgramLabel)
        default:
            return partial("\(tokenProgramLabel) instruction", accounts: accounts, dataLength: data.count)
        }
    }

    private static func parseTransfer(accounts: [DecodedAccountMeta], data: Data, checked: Bool, tokenProgramLabel: String) -> TransactionParsedInstruction {
        guard let rawAmount = TransactionInstructionParserFormatting.readUInt64LE(data, offset: 1) else {
            return partial("\(tokenProgramLabel) transfer", accounts: accounts, dataLength: data.count)
        }
        let decimals = checked && data.count >= 10 ? data[9] : nil
        let source = TransactionInstructionParserFormatting.account(accounts, 0)
        let mint = checked ? TransactionInstructionParserFormatting.account(accounts, 1) : nil
        let destination = TransactionInstructionParserFormatting.account(accounts, checked ? 2 : 1)
        let authority = TransactionInstructionParserFormatting.account(accounts, checked ? 3 : 2)
        var details: [TransactionInstructionDetail] = [
            .init(label: "Source", value: source ?? "unavailable"),
            .init(label: "Destination", value: destination ?? "unavailable"),
            .init(label: "Authority", value: authority ?? "unavailable"),
            .init(label: "Raw amount", value: "\(rawAmount)")
        ]
        if let mint {
            details.insert(.init(label: "Mint", value: mint), at: 2)
        }
        if let decimals {
            details.append(.init(label: "Decimals", value: "\(decimals)"))
            details.append(.init(label: "UI amount", value: TransactionInstructionParserFormatting.tokenAmount(rawAmount: rawAmount, decimals: decimals)))
        }
        let amountText = decimals.map { TransactionInstructionParserFormatting.tokenAmount(rawAmount: rawAmount, decimals: $0) } ?? "\(rawAmount) raw units"
        return TransactionParsedInstruction(
            status: .recognized,
            action: checked ? "\(tokenProgramLabel) TransferChecked \(amountText)" : "\(tokenProgramLabel) Transfer \(amountText)",
            details: details,
            riskHints: ["Token transfer"],
            explanationFragment: "This transaction transfers \(amountText) from token account \(short(source)) to \(short(destination))."
        )
    }

    private static func parseApprove(accounts: [DecodedAccountMeta], data: Data, checked: Bool, tokenProgramLabel: String) -> TransactionParsedInstruction {
        guard let rawAmount = TransactionInstructionParserFormatting.readUInt64LE(data, offset: 1) else {
            return partial("\(tokenProgramLabel) approve delegate", accounts: accounts, dataLength: data.count)
        }
        let decimals = checked && data.count >= 10 ? data[9] : nil
        let source = TransactionInstructionParserFormatting.account(accounts, 0)
        let mint = checked ? TransactionInstructionParserFormatting.account(accounts, 1) : nil
        let delegate = TransactionInstructionParserFormatting.account(accounts, checked ? 2 : 1)
        let owner = TransactionInstructionParserFormatting.account(accounts, checked ? 3 : 2)
        var details: [TransactionInstructionDetail] = [
            .init(label: "Source", value: source ?? "unavailable"),
            .init(label: "Delegate", value: delegate ?? "unavailable"),
            .init(label: "Owner", value: owner ?? "unavailable"),
            .init(label: "Raw amount", value: "\(rawAmount)")
        ]
        if let mint {
            details.insert(.init(label: "Mint", value: mint), at: 1)
        }
        if let decimals {
            details.append(.init(label: "Decimals", value: "\(decimals)"))
            details.append(.init(label: "UI amount", value: TransactionInstructionParserFormatting.tokenAmount(rawAmount: rawAmount, decimals: decimals)))
        }
        return TransactionParsedInstruction(
            status: .recognized,
            action: checked ? "\(tokenProgramLabel) ApproveChecked delegate" : "\(tokenProgramLabel) Approve delegate",
            details: details,
            riskHints: ["Token delegate approval"],
            explanationFragment: "This transaction approves delegate \(short(delegate)) for token account \(short(source))."
        )
    }

    private static func parseRevoke(accounts: [DecodedAccountMeta], tokenProgramLabel: String) -> TransactionParsedInstruction {
        TransactionParsedInstruction(
            status: .recognized,
            action: "\(tokenProgramLabel) Revoke delegate",
            details: [
                .init(label: "Source", value: TransactionInstructionParserFormatting.account(accounts, 0) ?? "unavailable"),
                .init(label: "Owner", value: TransactionInstructionParserFormatting.account(accounts, 1) ?? "unavailable")
            ],
            riskHints: ["Token delegate approval"],
            explanationFragment: "This transaction revokes a token delegate."
        )
    }

    private static func parseCloseAccount(accounts: [DecodedAccountMeta], tokenProgramLabel: String) -> TransactionParsedInstruction {
        TransactionParsedInstruction(
            status: .recognized,
            action: "\(tokenProgramLabel) Close token account",
            details: [
                .init(label: "Account", value: TransactionInstructionParserFormatting.account(accounts, 0) ?? "unavailable"),
                .init(label: "Rent destination", value: TransactionInstructionParserFormatting.account(accounts, 1) ?? "unavailable"),
                .init(label: "Authority", value: TransactionInstructionParserFormatting.account(accounts, 2) ?? "unavailable")
            ],
            riskHints: ["Token account close"],
            explanationFragment: "This transaction closes token account \(short(TransactionInstructionParserFormatting.account(accounts, 0)))."
        )
    }

    private static func parseSetAuthority(accounts: [DecodedAccountMeta], data: Data, tokenProgramLabel: String) -> TransactionParsedInstruction {
        let authorityType = data.count >= 2 ? authorityTypeLabel(data[1]) : "unknown"
        let newAuthority = data.count >= 35 ? TransactionInstructionParserFormatting.readPubkey(data, offset: 3) : nil
        return TransactionParsedInstruction(
            status: data.count >= 2 ? .partial : .unknown,
            action: "\(tokenProgramLabel) Set authority",
            details: [
                .init(label: "Account or mint", value: TransactionInstructionParserFormatting.account(accounts, 0) ?? "unavailable"),
                .init(label: "Current authority", value: TransactionInstructionParserFormatting.account(accounts, 1) ?? "unavailable"),
                .init(label: "Authority type", value: authorityType),
                .init(label: "New authority", value: newAuthority ?? "not decoded")
            ],
            riskHints: ["Authority change"],
            explanationFragment: "This transaction changes token authority. Review the authority type and new authority carefully."
        )
    }

    private static func parseInitializeAccount(accounts: [DecodedAccountMeta], tokenProgramLabel: String) -> TransactionParsedInstruction {
        TransactionParsedInstruction(
            status: .recognized,
            action: "\(tokenProgramLabel) Initialize account",
            details: [
                .init(label: "Account", value: TransactionInstructionParserFormatting.account(accounts, 0) ?? "unavailable"),
                .init(label: "Mint", value: TransactionInstructionParserFormatting.account(accounts, 1) ?? "unavailable"),
                .init(label: "Owner", value: TransactionInstructionParserFormatting.account(accounts, 2) ?? "unavailable")
            ],
            riskHints: [],
            explanationFragment: "This transaction initializes a token account."
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

    private static func authorityTypeLabel(_ rawValue: UInt8) -> String {
        switch rawValue {
        case 0:
            return "Mint tokens"
        case 1:
            return "Freeze account"
        case 2:
            return "Account owner"
        case 3:
            return "Close account"
        default:
            return "Unknown"
        }
    }

    private static func short(_ value: String?) -> String {
        TransactionInstructionParserFormatting.short(value ?? "unknown")
    }
}
