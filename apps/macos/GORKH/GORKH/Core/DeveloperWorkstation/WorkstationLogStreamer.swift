import Foundation

struct WorkstationLogEntry: Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let cluster: WorkstationCluster
    let programID: String
    let signature: String?
    let line: String

    init(id: UUID = UUID(), timestamp: Date = Date(), cluster: WorkstationCluster, programID: String, signature: String?, line: String) {
        self.id = id
        self.timestamp = timestamp
        self.cluster = cluster
        self.programID = programID
        self.signature = signature
        self.line = AgentSafetyRedactor.redact(line)
    }
}

struct WorkstationLogStreamState: Equatable {
    let programID: String?
    let cluster: WorkstationCluster
    let isStreaming: Bool
    let entries: [WorkstationLogEntry]
    let maxEntries: Int

    static func idle(cluster: WorkstationCluster = .devnet, maxEntries: Int = 500) -> WorkstationLogStreamState {
        WorkstationLogStreamState(programID: nil, cluster: cluster, isStreaming: false, entries: [], maxEntries: maxEntries)
    }

    func started(programID: String) -> WorkstationLogStreamState {
        WorkstationLogStreamState(programID: programID, cluster: cluster, isStreaming: true, entries: entries, maxEntries: maxEntries)
    }

    func stopped() -> WorkstationLogStreamState {
        WorkstationLogStreamState(programID: programID, cluster: cluster, isStreaming: false, entries: entries, maxEntries: maxEntries)
    }

    func appending(_ entry: WorkstationLogEntry) -> WorkstationLogStreamState {
        let bounded = Array((entries + [entry]).suffix(maxEntries))
        return WorkstationLogStreamState(
            programID: programID,
            cluster: cluster,
            isStreaming: isStreaming,
            entries: bounded,
            maxEntries: maxEntries
        )
    }
}

struct WorkstationLogStreamPolicy {
    static func canStream(programID: String) -> WorkstationRPCPermission {
        SolanaAddressValidator.isValidAddress(programID)
            ? .allowed
            : .blocked("Enter a valid program id before starting logs.")
    }
}
