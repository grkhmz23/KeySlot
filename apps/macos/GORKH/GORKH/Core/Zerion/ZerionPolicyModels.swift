import Foundation

struct ZerionPolicySummary: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let allowedChains: [String]
    let expiresAt: Date?
    let deniesTransfers: Bool
    let deniesApprovals: Bool
    let allowlistCount: Int
    let walletBinding: String?
    let status: ZerionPolicyReadStatus
}

struct ZerionAgentTokenSummary: Codable, Equatable, Identifiable {
    let id: String
    let policyID: String?
    let status: ZerionSecretStatus
    let expiresAt: Date?

    static let unknown = ZerionAgentTokenSummary(
        id: "unknown",
        policyID: nil,
        status: .unknown,
        expiresAt: nil
    )
}

struct ZerionPolicyCenterSnapshot: Codable, Equatable {
    let policies: [ZerionPolicySummary]
    let tokens: [ZerionAgentTokenSummary]
    let status: ZerionPolicyReadStatus
    let unavailableReason: String?
    let updatedAt: Date

    static let unchecked = ZerionPolicyCenterSnapshot(
        policies: [],
        tokens: [],
        status: .unchecked,
        unavailableReason: nil,
        updatedAt: Date()
    )
}
