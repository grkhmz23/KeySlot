import CryptoKit
import Foundation
import Security

protocol MnemonicService: Sendable {
    func generate(wordCount: Int) throws -> [String]
    func normalize(_ phrase: String) -> String
    func validate(_ phrase: String) -> Bool
    func validateOrThrow(_ phrase: String) throws
    func seed(from phrase: String, passphrase: String) throws -> Data
}

enum MnemonicError: LocalizedError, Equatable {
    case entropyUnavailable(OSStatus)
    case invalidEntropyLength
    case unsupportedWordCount
    case unknownWord
    case invalidChecksum
    case invalidSeedRequest

    var errorDescription: String? {
        switch self {
        case .entropyUnavailable(let status):
            return "Secure entropy is unavailable with status \(status)."
        case .invalidEntropyLength:
            return "Mnemonic entropy length is invalid."
        case .unsupportedWordCount:
            return "Recovery phrase must contain a valid BIP39 word count."
        case .unknownWord:
            return "Recovery phrase contains a word outside the BIP39 English list."
        case .invalidChecksum:
            return "Recovery phrase checksum is invalid."
        case .invalidSeedRequest:
            return "Recovery phrase seed derivation request is invalid."
        }
    }
}

struct Bip39MnemonicService: MnemonicService {
    nonisolated static let shared = Bip39MnemonicService()

    private static let supportedWordCounts: Set<Int> = [12, 15, 18, 21, 24]
    private let wordlist: [String]
    private let wordIndex: [String: Int]

    init(wordlist: [String] = Bip39EnglishWordlist.words) {
        self.wordlist = wordlist
        self.wordIndex = Dictionary(uniqueKeysWithValues: wordlist.enumerated().map { ($0.element, $0.offset) })
    }

    func generate(wordCount: Int = 12) throws -> [String] {
        guard Self.supportedWordCounts.contains(wordCount) else {
            throw MnemonicError.unsupportedWordCount
        }

        let entropyBitCount = wordCount * 11 * 32 / 33
        guard entropyBitCount % 8 == 0 else {
            throw MnemonicError.invalidEntropyLength
        }

        var entropy = [UInt8](repeating: 0, count: entropyBitCount / 8)
        let status = SecRandomCopyBytes(kSecRandomDefault, entropy.count, &entropy)
        guard status == errSecSuccess else {
            throw MnemonicError.entropyUnavailable(status)
        }

        return try mnemonic(fromEntropy: Data(entropy))
    }

    func normalize(_ phrase: String) -> String {
        phrase
            .decomposedStringWithCompatibilityMapping
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func validate(_ phrase: String) -> Bool {
        (try? validateOrThrow(phrase)) != nil
    }

    func validateOrThrow(_ phrase: String) throws {
        let words = try normalizedWords(from: phrase)
        let totalBitCount = words.count * 11
        let entropyBitCount = totalBitCount * 32 / 33
        let checksumBitCount = totalBitCount - entropyBitCount

        guard entropyBitCount % 8 == 0, checksumBitCount > 0 else {
            throw MnemonicError.invalidEntropyLength
        }

        let phraseBits = try words.flatMap { word -> [Bool] in
            guard let index = wordIndex[word] else {
                throw MnemonicError.unknownWord
            }
            return bits(fromWordIndex: index)
        }

        let entropyBits = phraseBits.prefix(entropyBitCount)
        let checksumBits = Array(phraseBits.suffix(checksumBitCount))
        let entropy = Data(Self.bytes(fromBits: entropyBits))
        let expectedChecksum = Array(Self.bits(fromBytes: Array(SHA256.hash(data: entropy))).prefix(checksumBitCount))

        guard checksumBits == expectedChecksum else {
            throw MnemonicError.invalidChecksum
        }
    }

    func seed(from phrase: String, passphrase: String = "") throws -> Data {
        try validateOrThrow(phrase)
        let normalizedPhrase = normalize(phrase).decomposedStringWithCompatibilityMapping
        let normalizedPassphrase = passphrase.decomposedStringWithCompatibilityMapping

        guard let password = normalizedPhrase.data(using: .utf8),
              let salt = ("mnemonic" + normalizedPassphrase).data(using: .utf8) else {
            throw MnemonicError.invalidSeedRequest
        }

        return Self.pbkdf2HMACSHA512(
            password: password,
            salt: salt,
            iterations: 2_048,
            outputByteCount: 64
        )
    }

    func mnemonic(fromEntropy entropy: Data) throws -> [String] {
        let entropyBitCount = entropy.count * 8
        guard [128, 160, 192, 224, 256].contains(entropyBitCount) else {
            throw MnemonicError.invalidEntropyLength
        }
        guard wordlist.count == 2_048 else {
            throw MnemonicError.unsupportedWordCount
        }

        let checksumBitCount = entropyBitCount / 32
        var combinedBits = Self.bits(fromBytes: Array(entropy))
        combinedBits.append(contentsOf: Self.bits(fromBytes: Array(SHA256.hash(data: entropy))).prefix(checksumBitCount))

        return stride(from: 0, to: combinedBits.count, by: 11).map { offset in
            let index = combinedBits[offset..<(offset + 11)].reduce(0) { partial, bit in
                (partial << 1) | (bit ? 1 : 0)
            }
            return wordlist[index]
        }
    }

    private func normalizedWords(from phrase: String) throws -> [String] {
        let words = normalize(phrase).split(separator: " ").map(String.init)
        guard Self.supportedWordCounts.contains(words.count) else {
            throw MnemonicError.unsupportedWordCount
        }
        return words
    }

    private func bits(fromWordIndex index: Int) -> [Bool] {
        (0..<11).reversed().map { bit in
            ((index >> bit) & 1) == 1
        }
    }

    private static func bits(fromBytes bytes: [UInt8]) -> [Bool] {
        bytes.flatMap { byte in
            (0..<8).reversed().map { bit in
                ((byte >> bit) & 1) == 1
            }
        }
    }

    private static func bytes<S: Sequence>(fromBits bits: S) -> [UInt8] where S.Element == Bool {
        var byte: UInt8 = 0
        var bitCount = 0
        var bytes: [UInt8] = []

        for bit in bits {
            byte = (byte << 1) | (bit ? 1 : 0)
            bitCount += 1
            if bitCount == 8 {
                bytes.append(byte)
                byte = 0
                bitCount = 0
            }
        }

        return bytes
    }

    private static func pbkdf2HMACSHA512(
        password: Data,
        salt: Data,
        iterations: Int,
        outputByteCount: Int
    ) -> Data {
        let key = SymmetricKey(data: password)
        let hashByteCount = 64
        let blockCount = Int(ceil(Double(outputByteCount) / Double(hashByteCount)))
        var derived = Data()

        for blockIndex in 1...blockCount {
            var saltBlock = Data(salt)
            var bigEndianBlock = UInt32(blockIndex).bigEndian
            withUnsafeBytes(of: &bigEndianBlock) { buffer in
                saltBlock.append(contentsOf: buffer)
            }

            var u = Data(HMAC<SHA512>.authenticationCode(for: saltBlock, using: key))
            var t = Array(u)

            if iterations > 1 {
                for _ in 2...iterations {
                    u = Data(HMAC<SHA512>.authenticationCode(for: u, using: key))
                    let uBytes = Array(u)
                    for index in t.indices {
                        t[index] ^= uBytes[index]
                    }
                }
            }

            derived.append(contentsOf: t)
        }

        return Data(derived.prefix(outputByteCount))
    }
}
