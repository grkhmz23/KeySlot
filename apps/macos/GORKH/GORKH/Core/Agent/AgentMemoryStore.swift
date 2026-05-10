import Foundation

struct AgentMemoryEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let intentType: AgentIntentType
    let proposalType: AgentProposalType?
    let handoffTarget: AgentHandoffTarget?
    let summary: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        intentType: AgentIntentType,
        proposalType: AgentProposalType?,
        handoffTarget: AgentHandoffTarget?,
        summary: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.intentType = intentType
        self.proposalType = proposalType
        self.handoffTarget = handoffTarget
        self.summary = AgentSafetyRedactor.redact(summary)
        self.createdAt = createdAt
    }
}

struct AgentMemoryStore: Codable, Equatable {
    private(set) var entries: [AgentMemoryEntry]
    let limit: Int

    init(entries: [AgentMemoryEntry] = [], limit: Int = 20) {
        self.entries = Array(entries.prefix(limit))
        self.limit = limit
    }

    mutating func remember(intent: AgentIntentClassification, proposal: AgentProposal? = nil, result: AgentToolResult? = nil) {
        let summary = proposal?.summary ?? result?.summary ?? intent.summary
        let entry = AgentMemoryEntry(
            intentType: intent.intentType,
            proposalType: proposal?.type,
            handoffTarget: proposal?.handoffTarget,
            summary: summary
        )
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(limit))
    }

    mutating func clear() {
        entries.removeAll()
    }
}
