import Foundation

struct ZerionCLIHelpProbe: Codable, Equatable {
    let topHelpAvailable: Bool
    let swapHelpAvailable: Bool
    let agentHelpAvailable: Bool
    let swapCommandShape: ZerionSwapCommandShape
    let supportsJSONFlag: Bool
    let supportsWalletFlag: Bool
    let supportsChainFlag: Bool
    let checkedAt: Date

    static let unchecked = ZerionCLIHelpProbe(
        topHelpAvailable: false,
        swapHelpAvailable: false,
        agentHelpAvailable: false,
        swapCommandShape: .unchecked,
        supportsJSONFlag: false,
        supportsWalletFlag: false,
        supportsChainFlag: false,
        checkedAt: Date()
    )
}
enum ZerionCLIHelpParser {
    static func parse(topHelp: String, swapHelp: String, agentHelp: String, checkedAt: Date = Date()) -> ZerionCLIHelpProbe {
        let combined = [topHelp, swapHelp, agentHelp].joined(separator: "\n").lowercased()
        let swap = swapHelp.lowercased()
        let hasChainFirst = swap.contains("swap <chain> <amount> <from-token> <to-token>")
            || swap.contains("swap <chain> <amount> <from") && swap.contains("<to")
            || swap.contains("zerion swap base 1 usdc eth")
            || swap.contains("zerion swap solana 0.1 sol usdc")
        let hasTokenFirst = swap.contains("swap <from> <to> <amount>")
            || swap.contains("swap <from-token> <to-token> <amount>")
            || swap.contains("zerion swap usdc eth 100")

        let shape: ZerionSwapCommandShape
        switch (hasChainFirst, hasTokenFirst) {
        case (true, false):
            shape = .chainFirst
        case (false, true):
            shape = .tokenFirstWithChainFlag
        case (true, true):
            shape = .ambiguous
        case (false, false):
            shape = swap.isEmpty ? .unavailable : .unavailable
        }

        return ZerionCLIHelpProbe(
            topHelpAvailable: topHelp.isEmpty == false,
            swapHelpAvailable: swapHelp.isEmpty == false,
            agentHelpAvailable: agentHelp.isEmpty == false,
            swapCommandShape: shape,
            supportsJSONFlag: combined.contains("--json"),
            supportsWalletFlag: combined.contains("--wallet"),
            supportsChainFlag: combined.contains("--chain"),
            checkedAt: checkedAt
        )
    }
}
