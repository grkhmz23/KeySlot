import Foundation

final class AuditLog {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultAuditURL()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func record(_ event: AuditEvent) {
        let sanitized = AuditEvent(
            id: event.id,
            kind: event.kind,
            createdAt: event.createdAt,
            walletID: event.walletID,
            network: event.network,
            publicAddress: event.publicAddress,
            transactionSignature: event.transactionSignature,
            message: event.message,
            details: Redaction.safeDetails(event.details)
        )

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let data = try encoder.encode(sanitized)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data("\n".utf8))
            try handle.close()
        } catch {
            assertionFailure("Audit log write failed: \(error.localizedDescription)")
        }
    }

    func loadRecent(limit: Int = 100) -> [AuditEvent] {
        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let events = text
            .split(separator: "\n")
            .compactMap { line -> AuditEvent? in
                guard let data = line.data(using: .utf8) else {
                    return nil
                }
                return try? decoder.decode(AuditEvent.self, from: data)
            }

        return Array(events.suffix(limit).reversed())
    }

    private static func defaultAuditURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("GORKH", isDirectory: true)
            .appendingPathComponent("audit-log.jsonl")
    }
}
