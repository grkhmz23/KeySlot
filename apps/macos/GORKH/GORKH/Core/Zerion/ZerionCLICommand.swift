import Foundation

enum ZerionCLICommand: Equatable {
    case help
    case chains
    case walletList
    case agentListPolicies
    case agentListTokens
    case configList
    case portfolio(address: String)
    case positions(address: String)
    case history(address: String)
    case pnl(address: String)

    var name: String {
        switch self {
        case .help:
            return "help"
        case .chains:
            return "chains"
        case .walletList:
            return "wallet_list"
        case .agentListPolicies:
            return "agent_list_policies"
        case .agentListTokens:
            return "agent_list_tokens"
        case .configList:
            return "config_list"
        case .portfolio:
            return "portfolio"
        case .positions:
            return "positions"
        case .history:
            return "history"
        case .pnl:
            return "pnl"
        }
    }

    var arguments: [String] {
        switch self {
        case .help:
            return ["--help"]
        case .chains:
            return ["chains"]
        case .walletList:
            return ["wallet", "list"]
        case .agentListPolicies:
            return ["agent", "list-policies"]
        case .agentListTokens:
            return ["agent", "list-tokens"]
        case .configList:
            return ["config", "list"]
        case .portfolio(let address):
            return ["portfolio", address]
        case .positions(let address):
            return ["positions", address]
        case .history(let address):
            return ["history", address]
        case .pnl(let address):
            return ["pnl", address]
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .portfolio, .positions, .history, .pnl:
            return true
        case .help, .chains, .walletList, .agentListPolicies, .agentListTokens, .configList:
            return false
        }
    }

    static let blockedRuntimeTerms: Set<String> = [
        "swap",
        "bridge",
        "send",
        "sign-message",
        "sign-typed-data",
        "create-policy",
        "create-token",
        "revoke-token",
        "create",
        "import",
        "fund",
        "backup",
        "delete",
        "sync"
    ]
}

enum ZerionCLICommandValidationError: Error, Equatable, LocalizedError {
    case empty
    case blocked(String)
    case unsupported([String])
    case unsafeArgument(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Empty Zerion command."
        case .blocked(let term):
            return "Zerion command blocked in A1: \(term)."
        case .unsupported(let args):
            return "Zerion command is not in the A1 allowlist: \(args.joined(separator: " "))."
        case .unsafeArgument(let arg):
            return "Zerion command contains an unsafe argument: \(arg)."
        }
    }
}

enum ZerionCLICommandBuilder {
    static func command(from arguments: [String]) throws -> ZerionCLICommand {
        guard arguments.isEmpty == false else {
            throw ZerionCLICommandValidationError.empty
        }
        try validateNoUnsafeArgument(arguments)

        let lowered = arguments.map { $0.lowercased() }
        for term in ZerionCLICommand.blockedRuntimeTerms where lowered.contains(term) {
            throw ZerionCLICommandValidationError.blocked(term)
        }

        switch lowered {
        case ["--help"], ["help"]:
            return .help
        case ["chains"]:
            return .chains
        case ["wallet", "list"]:
            return .walletList
        case ["agent", "list-policies"]:
            return .agentListPolicies
        case ["agent", "list-tokens"]:
            return .agentListTokens
        case ["config", "list"]:
            return .configList
        default:
            if lowered.count == 2 {
                switch lowered[0] {
                case "portfolio":
                    return .portfolio(address: arguments[1])
                case "positions":
                    return .positions(address: arguments[1])
                case "history":
                    return .history(address: arguments[1])
                case "pnl":
                    return .pnl(address: arguments[1])
                default:
                    break
                }
            }
            throw ZerionCLICommandValidationError.unsupported(arguments)
        }
    }

    static func validateNoUnsafeArgument(_ arguments: [String]) throws {
        for argument in arguments {
            if argument.contains(";") ||
                argument.contains("|") ||
                argument.contains("&") ||
                argument.contains("`") ||
                argument.contains("$(") ||
                argument.contains("\n") {
                throw ZerionCLICommandValidationError.unsafeArgument(argument)
            }
        }
    }
}
