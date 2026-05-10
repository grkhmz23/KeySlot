import Foundation

enum TransactionStudioHandoffTarget: String, Codable, CaseIterable, Identifiable {
    case copySummary
    case agentExplanation
    case saveHistory
    case walletActivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copySummary:
            return "Copy summary"
        case .agentExplanation:
            return "Send to Agent"
        case .saveHistory:
            return "Save to Studio history"
        case .walletActivity:
            return "Open Wallet Activity"
        }
    }
}

struct TransactionStudioHandoff: Codable, Equatable, Identifiable {
    let id: UUID
    let target: TransactionStudioHandoffTarget
    let summary: String
    let createdAt: Date

    init(id: UUID = UUID(), target: TransactionStudioHandoffTarget, summary: String, createdAt: Date = Date()) {
        self.id = id
        self.target = target
        self.summary = summary
        self.createdAt = createdAt
    }
}
