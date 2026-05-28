import Foundation

struct DeveloperWorkstationTempCleanupResult: Codable, Equatable {
    let startedAt: Date
    let scannedCount: Int
    let removedCount: Int
    let failureCount: Int
    let directorySummary: String

    var message: String {
        "Temp keypair cleanup scanned \(scannedCount) managed candidates, removed \(removedCount), failures \(failureCount)."
    }
}

protocol DeveloperWorkstationTempCleaning {
    func cleanup() -> DeveloperWorkstationTempCleanupResult
}

struct DeveloperWorkstationTempCleanupService {
    let fileManager: FileManager
    let staleThreshold: TimeInterval
    let now: () -> Date

    init(
        fileManager: FileManager = .default,
        staleThreshold: TimeInterval = 24 * 60 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.staleThreshold = staleThreshold
        self.now = now
    }

    func cleanup() -> DeveloperWorkstationTempCleanupResult {
        cleanup(in: fileManager.temporaryDirectory)
    }

    func cleanup(in root: URL) -> DeveloperWorkstationTempCleanupResult {
        let startedAt = now()
        let summary = DeveloperWorkstationTempCleanupService.redactedDirectorySummary(root)

        guard root.isFileURL else {
            return DeveloperWorkstationTempCleanupResult(
                startedAt: startedAt,
                scannedCount: 0,
                removedCount: 0,
                failureCount: 1,
                directorySummary: summary
            )
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return DeveloperWorkstationTempCleanupResult(
                startedAt: startedAt,
                scannedCount: 0,
                removedCount: 0,
                failureCount: fileManager.fileExists(atPath: root.path) ? 1 : 0,
                directorySummary: summary
            )
        }

        var scanned = 0
        var removed = 0
        var failures = 0

        for directory in children where DeveloperWorkstationTempCleanupService.isManagedTempDirectory(directory) {
            scanned += 1
            let keypairURL = directory.appendingPathComponent(WorkstationTemporaryKeypairFilePolicy.fileName)
            guard fileManager.fileExists(atPath: keypairURL.path) else {
                continue
            }
            guard isStale(directory, referenceDate: startedAt) else {
                continue
            }
            do {
                try fileManager.removeItem(at: directory)
                removed += 1
            } catch {
                failures += 1
            }
        }

        return DeveloperWorkstationTempCleanupResult(
            startedAt: startedAt,
            scannedCount: scanned,
            removedCount: removed,
            failureCount: failures,
            directorySummary: summary
        )
    }

    private func isStale(_ url: URL, referenceDate: Date) -> Bool {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let modified = attributes?[.modificationDate] as? Date
        let created = attributes?[.creationDate] as? Date
        let timestamp = modified ?? created ?? Date(timeIntervalSince1970: 0)
        return referenceDate.timeIntervalSince(timestamp) >= staleThreshold
    }

    static func isManagedTempDirectory(_ url: URL) -> Bool {
        url.isFileURL && url.lastPathComponent.hasPrefix(WorkstationTemporaryKeypairFilePolicy.directoryPrefix)
    }

    static func redactedDirectorySummary(_ url: URL) -> String {
        let last = url.lastPathComponent.isEmpty ? "temp" : url.lastPathComponent
        return ".../\(last)"
    }
}

extension DeveloperWorkstationTempCleanupService: DeveloperWorkstationTempCleaning {}
