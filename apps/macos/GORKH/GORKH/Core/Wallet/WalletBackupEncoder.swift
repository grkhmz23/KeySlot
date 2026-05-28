import Foundation

enum WalletBackupEncoder {
    static func encode(_ payload: WalletBackupPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(payload)
    }

    static func decode(_ data: Data) throws -> WalletBackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(WalletBackupPayload.self, from: data)

        guard payload.schemaVersion == WalletBackupPayload.currentSchemaVersion else {
            throw WalletBackupError.unsupportedSchemaVersion(payload.schemaVersion)
        }

        guard !payload.walletPublicAddress.isEmpty,
              !payload.walletLabel.isEmpty,
              !payload.derivationPath.isEmpty else {
            throw WalletBackupError.invalidPayload
        }

        return payload
    }

    static func fileName(for profile: WalletProfile) -> String {
        let shortAddress = String(profile.publicAddress.prefix(8))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let dateString = dateFormatter.string(from: profile.createdAt)
        return "keyslot-wallet-\(shortAddress)-\(dateString).\(WalletBackupPayload.fileExtension)"
    }
}
