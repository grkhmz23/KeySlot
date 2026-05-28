import Foundation

enum TransactionInstructionLabeler {
    static let computeBudgetProgramID = "ComputeBudget111111111111111111111111111111"
    static let memoProgramID = "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr"
    static let memoProgramIDV1 = "Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo"
    static let addressLookupTableProgramID = "AddressLookupTab1e1111111111111111111111111"
    static let bpfUpgradeableLoaderProgramID = "BPFLoaderUpgradeab1e11111111111111111111111"
    static let jupiterV6ProgramID = "JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4"
    static let jupiterV4ProgramID = "JUP4Fb2cqiRUcaTHdrPC8h2gNsA2ETXiPDD33WcGuJB"
    static let orcaWhirlpoolProgramID = "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc"
    static let raydiumAMMV4ProgramID = "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8"
    static let raydiumCPMMProgramID = "CPMMoo8L3F4NbTegBCKVNunggL7H1ZpdTHKxQB5qKP1C"
    static let raydiumCLMMProgramID = "CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK"
    static let meteoraDLMMProgramID = "LBUZKhRxPF3XUpBCjp4YzTKgLccjZhTSDM9YuVaPwxo"
    static let kaminoProgramID = "KLend2g3c3s7eQY2qjD6xH53wSbmcT4kBvfPz2KQxK7"
    static let marginFiProgramID = "MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA"

    nonisolated static func label(for programID: String) -> String {
        switch programID {
        case SolanaConstants.systemProgramID:
            return "System Program"
        case SolanaConstants.splTokenProgramID:
            return "SPL Token"
        case SolanaConstants.token2022ProgramID:
            return "Token-2022"
        case SolanaConstants.associatedTokenAccountProgramID:
            return "Associated Token Account"
        case computeBudgetProgramID:
            return "Compute Budget"
        case memoProgramID, memoProgramIDV1:
            return "Memo"
        case addressLookupTableProgramID:
            return "Address Lookup Table"
        case jupiterV6ProgramID, jupiterV4ProgramID:
            return "Jupiter"
        case orcaWhirlpoolProgramID:
            return "Orca Whirlpool"
        case raydiumAMMV4ProgramID:
            return "Raydium AMM"
        case raydiumCPMMProgramID:
            return "Raydium CPMM"
        case raydiumCLMMProgramID:
            return "Raydium CLMM"
        case meteoraDLMMProgramID:
            return "Meteora DLMM"
        case kaminoProgramID:
            return "Kamino"
        case marginFiProgramID:
            return "MarginFi"
        case bpfUpgradeableLoaderProgramID:
            return "Upgradeable Loader"
        default:
            return "Unknown Program"
        }
    }

    static func decodedAction(programID: String, data: Data) -> String {
        switch programID {
        case SolanaConstants.systemProgramID:
            return systemAction(data)
        case SolanaConstants.splTokenProgramID, SolanaConstants.token2022ProgramID:
            return tokenAction(data)
        case SolanaConstants.associatedTokenAccountProgramID:
            return "Associated token account instruction"
        case computeBudgetProgramID:
            return "Compute budget instruction"
        case memoProgramID, memoProgramIDV1:
            return "Memo instruction"
        default:
            return "Unknown instruction data"
        }
    }

    static func instructionRiskHints(programID: String, data: Data) -> [String] {
        switch programID {
        case SolanaConstants.systemProgramID:
            return systemAction(data).contains("transfer") ? ["Native SOL transfer"] : []
        case SolanaConstants.splTokenProgramID, SolanaConstants.token2022ProgramID:
            let action = tokenAction(data)
            if action.contains("Approve") {
                return ["Token delegate approval"]
            }
            if action.contains("Close") {
                return ["Token account close"]
            }
            if action.contains("authority") {
                return ["Authority change"]
            }
            if action.contains("Transfer") {
                return ["Token transfer"]
            }
            return []
        case jupiterV6ProgramID, jupiterV4ProgramID, orcaWhirlpoolProgramID, raydiumAMMV4ProgramID, raydiumCPMMProgramID, raydiumCLMMProgramID, meteoraDLMMProgramID, kaminoProgramID, marginFiProgramID:
            return ["DeFi protocol interaction"]
        default:
            return label(for: programID) == "Unknown Program" ? ["Unknown program"] : []
        }
    }

    private static func systemAction(_ data: Data) -> String {
        guard data.count >= 4 else {
            return "System instruction"
        }
        let discriminator = UInt32(data[0]) | UInt32(data[1]) << 8 | UInt32(data[2]) << 16 | UInt32(data[3]) << 24
        switch discriminator {
        case 2:
            return "System transfer"
        case 0:
            return "Create account"
        case 1:
            return "Assign account"
        case 8:
            return "Allocate account"
        default:
            return "System instruction"
        }
    }

    private static func tokenAction(_ data: Data) -> String {
        guard let discriminator = data.first else {
            return "Token instruction"
        }
        switch discriminator {
        case 1:
            return "Initialize token account"
        case 3:
            return "Token Transfer"
        case 12:
            return "Token TransferChecked"
        case 4:
            return "Approve delegate"
        case 13:
            return "ApproveChecked delegate"
        case 5:
            return "Revoke delegate"
        case 6:
            return "Set authority"
        case 9:
            return "Close token account"
        case 14:
            return "MintToChecked"
        case 15:
            return "BurnChecked"
        default:
            return "Token instruction"
        }
    }
}
