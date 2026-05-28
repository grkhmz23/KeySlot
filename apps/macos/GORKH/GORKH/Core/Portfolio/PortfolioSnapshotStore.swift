import Foundation

final class PortfolioSnapshotStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maxSnapshots: Int

    init(fileURL: URL? = nil, maxSnapshots: Int = 100) {
        self.fileURL = fileURL ?? Self.defaultSnapshotURL()
        self.maxSnapshots = maxSnapshots
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [PortfolioSnapshot] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            return []
        }
        return (try? decoder.decode([PortfolioSnapshot].self, from: data)) ?? []
    }

    @discardableResult
    func append(_ snapshot: PortfolioSnapshot) throws -> [PortfolioSnapshot] {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var snapshots = load()
        snapshots.append(snapshot)
        snapshots = Array(snapshots.suffix(maxSnapshots))
        let data = try encoder.encode(snapshots)
        try data.write(to: fileURL, options: [.atomic])
        return snapshots
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func defaultSnapshotURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("KeySlot", isDirectory: true)
            .appendingPathComponent("portfolio-snapshots.json")
    }
}
