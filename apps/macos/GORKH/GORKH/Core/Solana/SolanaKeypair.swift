import CryptoKit
import Foundation

struct SolanaKeypair: Equatable {
    let seed: Data
    let publicKey: Data

    var publicAddress: String {
        Base58.encode(publicKey)
    }

    init(seed: Data) throws {
        guard seed.count == 32 else {
            throw WalletVaultError.invalidSecret
        }

        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        self.seed = seed
        self.publicKey = privateKey.publicKey.rawRepresentation
    }

    static func generate() throws -> SolanaKeypair {
        let privateKey = Curve25519.Signing.PrivateKey()
        return try SolanaKeypair(seed: privateKey.rawRepresentation)
    }

    static func importPrivateKey(_ text: String) throws -> SolanaKeypair {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes: [UInt8]

        if trimmed.hasPrefix("[") {
            bytes = try parseJSONByteArray(trimmed)
        } else if let decoded = Base58.decode(trimmed) {
            bytes = decoded
        } else {
            throw WalletVaultError.invalidSecret
        }

        guard bytes.count == 32 || bytes.count == 64 else {
            throw WalletVaultError.invalidSecret
        }

        let seed = Data(bytes.prefix(32))
        let keypair = try SolanaKeypair(seed: seed)

        if bytes.count == 64 {
            let importedPublicKey = Data(bytes.suffix(32))
            guard importedPublicKey == keypair.publicKey else {
                throw WalletVaultError.invalidSecret
            }
        }

        return keypair
    }

    private static func parseJSONByteArray(_ text: String) throws -> [UInt8] {
        guard let data = text.data(using: .utf8),
              let raw = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw WalletVaultError.invalidSecret
        }

        return try raw.map { value in
            guard let number = value as? NSNumber else {
                throw WalletVaultError.invalidSecret
            }

            let integer = number.intValue
            guard integer >= 0, integer <= 255 else {
                throw WalletVaultError.invalidSecret
            }
            return UInt8(integer)
        }
    }
}
