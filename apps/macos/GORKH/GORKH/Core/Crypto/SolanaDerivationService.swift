import CryptoKit
import Foundation

struct SolanaDerivationService {
    private let mnemonicService: any MnemonicService

    init() {
        self.init(mnemonicService: Bip39MnemonicService.shared)
    }

    init(mnemonicService: any MnemonicService) {
        self.mnemonicService = mnemonicService
    }

    func deriveKeypair(
        mnemonic: String,
        path: DerivationPath = .defaultSolana
    ) throws -> SolanaKeypair {
        let seed = try deriveSigningSeed(mnemonic: mnemonic, path: path)
        return try SolanaKeypair(seed: seed)
    }

    func deriveKeypair(
        mnemonic: String,
        vaultPassphrase: String,
        path: DerivationPath = .defaultSolana
    ) throws -> SolanaKeypair {
        let seed = try deriveSigningSeed(mnemonic: mnemonic, vaultPassphrase: vaultPassphrase, path: path)
        return try SolanaKeypair(seed: seed)
    }

    func deriveSigningSeed(
        mnemonic: String,
        path: DerivationPath = .defaultSolana
    ) throws -> Data {
        let bip39Seed = try mnemonicService.seed(from: mnemonic, passphrase: "")
        return try deriveSigningSeed(bip39Seed: bip39Seed, path: path)
    }

    func deriveSigningSeed(
        mnemonic: String,
        vaultPassphrase: String,
        path: DerivationPath = .defaultSolana
    ) throws -> Data {
        let bip39Seed = try mnemonicService.seed(from: mnemonic, passphrase: vaultPassphrase)
        return try deriveSigningSeed(bip39Seed: bip39Seed, path: path)
    }

    func deriveSigningSeed(
        bip39Seed: Data,
        path: DerivationPath = .defaultSolana
    ) throws -> Data {
        guard bip39Seed.count == 64 else {
            throw SolanaDerivationError.invalidSeed
        }

        // SLIP-0010 Ed25519 hardened derivation. Non-hardened Ed25519 child
        // derivation is deliberately unsupported for Solana wallet paths.
        var digest = Self.hmacSHA512(
            key: Data("ed25519 seed".utf8),
            data: bip39Seed
        )
        var privateKey = Data(digest.prefix(32))
        var chainCode = Data(digest.suffix(32))

        for hardenedIndex in path.hardenedIndexes {
            var data = Data([0x00])
            data.append(privateKey)
            var bigEndianIndex = hardenedIndex.bigEndian
            withUnsafeBytes(of: &bigEndianIndex) { buffer in
                data.append(contentsOf: buffer)
            }

            digest = Self.hmacSHA512(key: chainCode, data: data)
            privateKey = Data(digest.prefix(32))
            chainCode = Data(digest.suffix(32))
        }

        return privateKey
    }

    private static func hmacSHA512(key: Data, data: Data) -> Data {
        Data(HMAC<SHA512>.authenticationCode(
            for: data,
            using: SymmetricKey(data: key)
        ))
    }
}

enum SolanaDerivationError: LocalizedError, Equatable {
    case invalidSeed

    var errorDescription: String? {
        switch self {
        case .invalidSeed:
            return "BIP39 seed must be 64 bytes."
        }
    }
}
