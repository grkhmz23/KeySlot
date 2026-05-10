import Foundation

enum ZerionSwapCommandBuilderError: Error, Equatable, LocalizedError {
    case unsupportedShape
    case unsafeValue(String)
    case missingWallet

    var errorDescription: String? {
        switch self {
        case .unsupportedShape:
            return "Zerion swap command shape is not validated for execution."
        case .unsafeValue(let value):
            return "Zerion swap command value is unsafe: \(value)."
        case .missingWallet:
            return "A separate Zerion wallet name is required."
        }
    }
}

enum ZerionSwapCommandBuilder {
    static func build(
        proposal: ZerionTinySwapProposal,
        helpProbe: ZerionCLIHelpProbe
    ) throws -> ZerionSwapCommandPlan {
        guard helpProbe.swapCommandShape.canBuildTinySwap else {
            throw ZerionSwapCommandBuilderError.unsupportedShape
        }

        let wallet = proposal.zerionWalletName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard wallet.isEmpty == false else {
            throw ZerionSwapCommandBuilderError.missingWallet
        }

        let amount = NSDecimalNumber(decimal: proposal.amount).stringValue
        let coreValues = [wallet, proposal.chain.rawValue, proposal.fromToken, proposal.toToken, amount]
        for value in coreValues {
            try validateValue(value)
        }

        var arguments: [String]
        switch helpProbe.swapCommandShape {
        case .chainFirst:
            arguments = ["swap", proposal.chain.rawValue, amount, proposal.fromToken, proposal.toToken]
        case .tokenFirstWithChainFlag:
            arguments = ["swap", proposal.fromToken, proposal.toToken, amount, "--chain", proposal.chain.rawValue]
        case .unchecked, .unavailable, .ambiguous:
            throw ZerionSwapCommandBuilderError.unsupportedShape
        }

        if helpProbe.supportsWalletFlag {
            arguments.append(contentsOf: ["--wallet", wallet])
        }
        if helpProbe.supportsJSONFlag {
            arguments.append("--json")
        }

        try ZerionCLICommandBuilder.validateNoUnsafeArgument(arguments)
        return ZerionSwapCommandPlan(
            commandName: "zerion_tiny_swap",
            arguments: arguments,
            redactedPreview: ZerionRedaction.redact((["zerion"] + arguments).joined(separator: " ")),
            shape: helpProbe.swapCommandShape,
            requiresAPIKey: true
        )
    }

    private static func validateValue(_ value: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-")
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ZerionSwapCommandBuilderError.unsafeValue(value)
        }
    }
}
