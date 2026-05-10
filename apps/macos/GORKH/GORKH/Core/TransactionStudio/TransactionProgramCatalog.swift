import Foundation

enum TransactionProgramCategory: String, Codable, Equatable, CaseIterable {
    case system
    case token
    case token2022
    case associatedToken
    case computeBudget
    case memo
    case addressLookupTable
    case aggregator
    case liquidity
    case lending
    case privacy
    case unknown

    var title: String {
        switch self {
        case .system:
            return "System"
        case .token:
            return "Token"
        case .token2022:
            return "Token-2022"
        case .associatedToken:
            return "Associated Token"
        case .computeBudget:
            return "Compute Budget"
        case .memo:
            return "Memo"
        case .addressLookupTable:
            return "Address Lookup Table"
        case .aggregator:
            return "Aggregator"
        case .liquidity:
            return "Liquidity"
        case .lending:
            return "Lending"
        case .privacy:
            return "Private"
        case .unknown:
            return "Unknown"
        }
    }
}

struct TransactionProgramCatalogEntry: Codable, Equatable, Identifiable {
    var id: String { programID }

    let programID: String
    let label: String
    let category: TransactionProgramCategory
    let defaultRiskHint: String
    let explanation: String
}

enum TransactionProgramCatalog {
    static func entry(for programID: String) -> TransactionProgramCatalogEntry {
        let label = TransactionInstructionLabeler.label(for: programID)
        let category: TransactionProgramCategory
        let risk: String
        let explanation: String

        switch label {
        case "System Program":
            category = .system
            risk = "Can move SOL or change account allocation/ownership."
            explanation = "System Program instructions manage SOL transfers and base account state."
        case "SPL Token":
            category = .token
            risk = "Can move tokens or change token account authority."
            explanation = "SPL Token instructions affect token accounts, mints, approvals, and closures."
        case "Token-2022":
            category = .token2022
            risk = "Token extensions may add hooks, fees, or authority behavior."
            explanation = "Token-2022 extends SPL Token behavior; extension data should be reviewed when available."
        case "Associated Token Account":
            category = .associatedToken
            risk = "Usually creates or recovers token accounts; verify owner and mint."
            explanation = "Associated Token Account instructions derive token accounts for a wallet and mint."
        case "Compute Budget":
            category = .computeBudget
            risk = "Can raise compute limits or priority fees."
            explanation = "Compute Budget instructions change compute allocation and priority fee settings."
        case "Memo":
            category = .memo
            risk = "Memo text is informational but should still be reviewed."
            explanation = "Memo instructions attach text to a transaction."
        case "Address Lookup Table":
            category = .addressLookupTable
            risk = "Can reference additional accounts not present in the static account list."
            explanation = "Address lookup tables expand v0 transaction account lists."
        case "Jupiter":
            category = .aggregator
            risk = "Aggregator route may move tokens across several programs."
            explanation = "Jupiter instructions route swaps through one or more liquidity venues."
        case "Orca Whirlpool", "Raydium AMM", "Raydium CPMM", "Raydium CLMM", "Meteora DLMM":
            category = .liquidity
            risk = "Liquidity protocol interaction; review token movement and simulation logs."
            explanation = "\(label) is a DeFi liquidity protocol."
        case "Kamino", "MarginFi":
            category = .lending
            risk = "Lending protocol interaction; review obligations and health effects."
            explanation = "\(label) is a lending or leverage-related protocol."
        case "Cloak":
            category = .privacy
            risk = "Private-state interaction; review local private state requirements."
            explanation = "Cloak instructions interact with private wallet state."
        default:
            category = .unknown
            risk = "Unknown program. Verify program ID before approval."
            explanation = "GORKH does not have a reviewed label for this program."
        }

        return TransactionProgramCatalogEntry(
            programID: programID,
            label: label,
            category: category,
            defaultRiskHint: risk,
            explanation: explanation
        )
    }
}
