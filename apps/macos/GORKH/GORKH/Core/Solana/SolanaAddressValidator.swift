import Foundation

enum SolanaAddressValidator {
    static func isValidAddress(_ value: String) -> Bool {
        decodeAddress(value) != nil
    }

    static func decodeAddress(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let decoded = Base58.decode(trimmed), decoded.count == 32 else {
            return nil
        }
        return Data(decoded)
    }
}

enum SolanaAmountValidator {
    static func lamports(fromSOLText value: String) throws -> UInt64 {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SolanaValidationError.invalidAmount("Enter an amount.")
        }

        guard trimmed.range(of: #"^\d+(\.\d{1,9})?$"#, options: .regularExpression) != nil else {
            throw SolanaValidationError.invalidAmount("Use up to 9 decimal places.")
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard let whole = UInt64(parts[0]) else {
            throw SolanaValidationError.invalidAmount("Amount is too large.")
        }

        var lamports = whole.multipliedReportingOverflow(by: SolanaConstants.lamportsPerSol)
        guard !lamports.overflow else {
            throw SolanaValidationError.invalidAmount("Amount is too large.")
        }

        if parts.count == 2 {
            let fractional = String(parts[1])
            let padded = fractional.padding(toLength: 9, withPad: "0", startingAt: 0)
            guard let fractionalLamports = UInt64(padded) else {
                throw SolanaValidationError.invalidAmount("Amount is invalid.")
            }

            let added = lamports.partialValue.addingReportingOverflow(fractionalLamports)
            guard !added.overflow else {
                throw SolanaValidationError.invalidAmount("Amount is too large.")
            }
            lamports = (partialValue: added.partialValue, overflow: false)
        }

        guard lamports.partialValue > 0 else {
            throw SolanaValidationError.invalidAmount("Amount must be greater than 0.")
        }

        return lamports.partialValue
    }
}

enum SolanaValidationError: LocalizedError, Equatable {
    case invalidAddress(String)
    case invalidAmount(String)

    var errorDescription: String? {
        switch self {
        case .invalidAddress(let message), .invalidAmount(let message):
            return message
        }
    }
}

enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    private static let indexes: [UInt8: Int] = {
        var map = [UInt8: Int]()
        for (index, character) in alphabet.enumerated() {
            map[character] = index
        }
        return map
    }()

    static func encode(_ data: Data) -> String {
        encode(Array(data))
    }

    static func encode(_ input: [UInt8]) -> String {
        guard !input.isEmpty else {
            return ""
        }

        var digits = [Int](repeating: 0, count: 1)
        for byte in input {
            var carry = Int(byte)
            for index in 0..<digits.count {
                carry += digits[index] << 8
                digits[index] = carry % 58
                carry /= 58
            }

            while carry > 0 {
                digits.append(carry % 58)
                carry /= 58
            }
        }

        let leadingZeros = input.prefix { $0 == 0 }.count
        let encodedDigits = digits.reversed().drop { $0 == 0 }.map { digit in
            String(UnicodeScalar(alphabet[digit]))
        }.joined()

        return String(repeating: "1", count: leadingZeros) + encodedDigits
    }

    static func decode(_ input: String) -> [UInt8]? {
        guard !input.isEmpty else {
            return []
        }

        var bytes = [Int](repeating: 0, count: 1)
        for character in input.utf8 {
            guard let value = indexes[character] else {
                return nil
            }

            var carry = value
            for index in 0..<bytes.count {
                carry += bytes[index] * 58
                bytes[index] = carry & 0xff
                carry >>= 8
            }

            while carry > 0 {
                bytes.append(carry & 0xff)
                carry >>= 8
            }
        }

        let leadingZeros = input.utf8.prefix { $0 == alphabet[0] }.count
        let decoded = bytes.reversed().drop { $0 == 0 }.map { UInt8($0) }
        return Array(repeating: UInt8(0), count: leadingZeros) + decoded
    }
}
