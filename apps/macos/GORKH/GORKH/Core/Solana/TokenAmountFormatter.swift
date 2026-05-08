import Foundation

enum TokenAmountFormatter {
    static func format(rawAmount: UInt64, decimals: UInt8) -> String {
        guard decimals > 0 else {
            return String(rawAmount)
        }

        let decimalPlaces = Int(decimals)
        let raw = String(rawAmount)
        let whole: String
        let fractional: String

        if raw.count <= decimalPlaces {
            whole = "0"
            fractional = String(repeating: "0", count: decimalPlaces - raw.count) + raw
        } else {
            let splitIndex = raw.index(raw.endIndex, offsetBy: -decimalPlaces)
            whole = String(raw[..<splitIndex])
            fractional = String(raw[splitIndex...])
        }

        let trimmedFractional = fractional.replacingOccurrences(
            of: #"0+$"#,
            with: "",
            options: .regularExpression
        )

        return trimmedFractional.isEmpty ? whole : "\(whole).\(trimmedFractional)"
    }

    static func rawAmount(fromUIAmount value: String, decimals: UInt8) throws -> UInt64 {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SolanaValidationError.invalidAmount("Enter a token amount.")
        }

        guard trimmed.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil else {
            throw SolanaValidationError.invalidAmount("Use a plain decimal token amount.")
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, let wholePart = parts.first else {
            throw SolanaValidationError.invalidAmount("Token amount is invalid.")
        }

        let fractionalPart = parts.count == 2 ? String(parts[1]) : ""
        let decimalPlaces = Int(decimals)
        guard fractionalPart.count <= decimalPlaces else {
            throw SolanaValidationError.invalidAmount("Use no more than \(decimalPlaces) decimal places for this token.")
        }

        let paddedFractional = fractionalPart.padding(toLength: decimalPlaces, withPad: "0", startingAt: 0)
        let rawString = String(wholePart) + paddedFractional
        let normalizedRaw = rawString.drop { $0 == "0" }
        guard !normalizedRaw.isEmpty else {
            throw SolanaValidationError.invalidAmount("Amount must be greater than 0.")
        }

        if normalizedRaw.count > String(UInt64.max).count {
            throw SolanaValidationError.invalidAmount("Token amount is too large.")
        }

        let normalized = String(normalizedRaw)
        if normalized.count == String(UInt64.max).count, normalized > String(UInt64.max) {
            throw SolanaValidationError.invalidAmount("Token amount is too large.")
        }

        guard let rawAmount = UInt64(normalized), rawAmount > 0 else {
            throw SolanaValidationError.invalidAmount("Token amount is invalid.")
        }

        return rawAmount
    }
}
