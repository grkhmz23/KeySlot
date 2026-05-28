import Foundation

final class TransactionStudioHistoryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [TransactionStudioHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? decoder.decode([TransactionStudioHistoryEntry].self, from: data)) ?? []
    }

    func append(_ entry: TransactionStudioHistoryEntry, limit: Int = 100) {
        var entries = load()
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(limit))
        save(entries)
    }

    func clear() {
        save([])
    }

    private func save(_ entries: [TransactionStudioHistoryEntry]) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Transaction Studio history write failed: \(error.localizedDescription)")
        }
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("transaction-studio-history.json")
    }
}
