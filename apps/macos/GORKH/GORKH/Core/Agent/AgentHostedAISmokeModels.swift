import Foundation

struct AgentHostedAISmokeSummary: Codable, Equatable {
    enum Status: String, Codable {
        case notRun = "not_run"
        case passed
        case failed
    }

    let status: Status
    let scenario: String
    let endpointHost: String?
    let requestID: String?
    let blockedToolCount: Int
    let checkedAt: Date

    static let notRun = AgentHostedAISmokeSummary(
        status: .notRun,
        scenario: "none",
        endpointHost: nil,
        requestID: nil,
        blockedToolCount: 0,
        checkedAt: Date(timeIntervalSince1970: 0)
    )
}
