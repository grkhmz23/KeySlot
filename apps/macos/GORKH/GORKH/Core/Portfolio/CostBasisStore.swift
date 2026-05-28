import Foundation

final class CostBasisStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultCostBasisURL()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [CostBasisEntry] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            return []
        }
        return (try? decoder.decode([CostBasisEntry].self, from: data)) ?? []
    }

    @discardableResult
    func save(_ entries: [CostBasisEntry]) throws -> [CostBasisEntry] {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let sorted = entries.sorted {
            if $0.acquisitionDate == $1.acquisitionDate {
                return $0.tokenMint < $1.tokenMint
            }
            return $0.acquisitionDate < $1.acquisitionDate
        }
        let data = try encoder.encode(sorted)
        try data.write(to: fileURL, options: [.atomic])
        return sorted
    }

    @discardableResult
    func upsert(_ entry: CostBasisEntry) throws -> [CostBasisEntry] {
        var entries = load()
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        return try save(entries)
    }

    @discardableResult
    func remove(id: UUID) throws -> [CostBasisEntry] {
        try save(load().filter { $0.id != id })
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func defaultCostBasisURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("portfolio-cost-basis.json")
    }
}
