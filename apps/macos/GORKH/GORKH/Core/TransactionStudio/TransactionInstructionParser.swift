import Foundation

enum TransactionInstructionParser {
    static func parse(programID: String, programLabel: String, accounts: [DecodedAccountMeta], data: Data) -> TransactionParsedInstruction {
        switch programID {
        case SolanaConstants.systemProgramID:
            return SystemInstructionParser.parse(accounts: accounts, data: data)
        case SolanaConstants.splTokenProgramID:
            return SPLTokenInstructionParser.parse(accounts: accounts, data: data, tokenProgramLabel: "SPL Token")
        case SolanaConstants.token2022ProgramID:
            return Token2022InstructionParser.parse(accounts: accounts, data: data)
        case SolanaConstants.associatedTokenAccountProgramID:
            return ATAInstructionParser.parse(accounts: accounts, data: data)
        case TransactionInstructionLabeler.computeBudgetProgramID:
            return ComputeBudgetInstructionParser.parse(data: data)
        case TransactionInstructionLabeler.memoProgramID, TransactionInstructionLabeler.memoProgramIDV1:
            return MemoInstructionParser.parse(data: data)
        case TransactionInstructionLabeler.jupiterV6ProgramID, TransactionInstructionLabeler.jupiterV4ProgramID:
            return JupiterInstructionLabeler.parse(programLabel: programLabel, accounts: accounts, data: data)
        default:
            if programLabel == "Unknown Program" {
                return .unknown
            }
            return TransactionParsedInstruction(
                status: .partial,
                action: "\(programLabel) instruction",
                details: [
                    TransactionInstructionDetail(label: "Program", value: programID),
                    TransactionInstructionDetail(label: "Raw data", value: "\(data.count) byte(s)")
                ],
                riskHints: TransactionInstructionLabeler.instructionRiskHints(programID: programID, data: data),
                explanationFragment: "\(programLabel) is involved; review protocol-specific details before approval."
            )
        }
    }
}

enum TransactionInstructionParserFormatting {
    static func short(_ value: String) -> String {
        guard value.count > 16 else {
            return value
        }
        return "\(value.prefix(6))...\(value.suffix(6))"
    }

    static func detail(_ label: String, _ value: String?) -> TransactionInstructionDetail {
        TransactionInstructionDetail(label: label, value: value ?? "unavailable")
    }

    static func account(_ accounts: [DecodedAccountMeta], _ index: Int) -> String? {
        guard index >= 0, index < accounts.count else {
            return nil
        }
        return accounts[index].address
    }

    static func readUInt32LE(_ data: Data, offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else {
            return nil
        }
        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    static func readUInt64LE(_ data: Data, offset: Int) -> UInt64? {
        guard offset >= 0, offset + 8 <= data.count else {
            return nil
        }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(data[offset + index]) << UInt64(index * 8)
        }
        return value
    }

    static func readPubkey(_ data: Data, offset: Int) -> String? {
        guard offset >= 0, offset + 32 <= data.count else {
            return nil
        }
        return Base58.encode(data.subdata(in: offset..<(offset + 32)))
    }

    static func solAmount(lamports: UInt64) -> String {
        let whole = lamports / 1_000_000_000
        let fractional = lamports % 1_000_000_000
        if fractional == 0 {
            return "\(whole) SOL"
        }
        var fraction = String(format: "%09llu", fractional)
        while fraction.last == "0" {
            fraction.removeLast()
        }
        return "\(whole).\(fraction) SOL"
    }

    static func tokenAmount(rawAmount: UInt64, decimals: UInt8?) -> String {
        guard let decimals, decimals > 0, decimals < 19 else {
            return "\(rawAmount)"
        }
        let scale = UInt64(pow(10.0, Double(decimals)))
        guard scale > 0 else {
            return "\(rawAmount)"
        }
        let whole = rawAmount / scale
        let fractional = rawAmount % scale
        if fractional == 0 {
            return "\(whole)"
        }
        var fraction = String(format: "%0*llu", Int(decimals), fractional)
        while fraction.last == "0" {
            fraction.removeLast()
        }
        return "\(whole).\(fraction)"
    }
}
