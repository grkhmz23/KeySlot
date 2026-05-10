import Foundation

enum ShieldReviewStatus: String, Codable, Equatable, Hashable, CaseIterable {
    case ready
    case unavailable
    case externalSummary

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .unavailable:
            return "Unavailable"
        case .externalSummary:
            return "External summary"
        }
    }
}

enum ShieldReviewRiskLevel: String, Codable, Equatable, Hashable, CaseIterable {
    case low
    case medium
    case high
    case unknown

    var title: String {
        rawValue.capitalized
    }

    init(_ studioLevel: TransactionRiskLevel) {
        switch studioLevel {
        case .low:
            self = .low
        case .medium:
            self = .medium
        case .high:
            self = .high
        case .unknown:
            self = .unknown
        }
    }
}

struct ShieldReviewRiskFlag: Codable, Equatable, Identifiable {
    var id: String { "\(kind):\(message)" }

    let kind: String
    let level: ShieldReviewRiskLevel
    let message: String
}

enum ShieldReviewSimulationStatus: String, Codable, Equatable, Hashable {
    case notRun
    case success
    case failed
    case unavailable

    var title: String {
        switch self {
        case .notRun:
            return "Not run"
        case .success:
            return "Passed"
        case .failed:
            return "Failed"
        case .unavailable:
            return "Unavailable"
        }
    }

    init(_ simulation: SimulationResult?) {
        guard let simulation else {
            self = .notRun
            return
        }
        switch simulation.status {
        case .success:
            self = .success
        case .failed:
            self = .failed
        case .unavailable:
            self = .unavailable
        }
    }

    init(_ simulation: TransactionStudioSimulationSummary) {
        switch simulation.status {
        case .notRun:
            self = .notRun
        case .success:
            self = .success
        case .failed:
            self = .failed
        case .unavailable:
            self = .unavailable
        }
    }
}

struct ShieldReviewSimulationSummary: Codable, Equatable {
    let status: ShieldReviewSimulationStatus
    let computeUnits: UInt64?
    let estimatedFeeLamports: UInt64?
    let errorMessage: String?
    let logPreview: [String]

    static let notRun = ShieldReviewSimulationSummary(
        status: .notRun,
        computeUnits: nil,
        estimatedFeeLamports: nil,
        errorMessage: nil,
        logPreview: []
    )

    init(
        status: ShieldReviewSimulationStatus,
        computeUnits: UInt64?,
        estimatedFeeLamports: UInt64?,
        errorMessage: String?,
        logPreview: [String]
    ) {
        self.status = status
        self.computeUnits = computeUnits
        self.estimatedFeeLamports = estimatedFeeLamports
        self.errorMessage = errorMessage
        self.logPreview = logPreview
    }

    init(_ simulation: SimulationResult?) {
        self.status = ShieldReviewSimulationStatus(simulation)
        self.computeUnits = nil
        self.estimatedFeeLamports = simulation?.estimatedFeeLamports
        self.errorMessage = simulation?.errorMessage
        self.logPreview = simulation.map { Array($0.logs.prefix(8)) } ?? []
    }
}

struct ShieldReviewParsedAction: Codable, Equatable, Identifiable {
    var id: String { "\(label):\(detail)" }

    let label: String
    let detail: String
    let assetMovement: String?
}

enum ShieldReviewApprovalRequirement: String, Codable, Equatable, Hashable, CaseIterable, Identifiable {
    case review
    case simulation
    case explicitApproval
    case localAuthentication
    case mainnetPhrase
    case nativeSigner
    case destinationApproval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .review:
            return "Review"
        case .simulation:
            return "Simulation"
        case .explicitApproval:
            return "Explicit approval"
        case .localAuthentication:
            return "LocalAuthentication"
        case .mainnetPhrase:
            return "Mainnet phrase"
        case .nativeSigner:
            return "Native signer"
        case .destinationApproval:
            return "Destination approval"
        }
    }
}

struct ShieldReviewHandoff: Codable, Equatable {
    let safeSummary: String
    let temporaryRawPayloadAvailable: Bool
    let payloadAvailability: ShieldReviewPayloadAvailability
    let sourceFlow: ShieldReviewSourceFlow
    let note: String
}

struct ShieldReviewSummary: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let status: ShieldReviewStatus
    let riskLevel: ShieldReviewRiskLevel
    let parsedActions: [ShieldReviewParsedAction]
    let programLabels: [String]
    let signerCount: Int
    let writableCount: Int
    let unknownInstructionCount: Int
    let riskFlags: [ShieldReviewRiskFlag]
    let simulation: ShieldReviewSimulationSummary
    let explanation: String
    let approvalRequirements: [ShieldReviewApprovalRequirement]
    let unavailableReason: String?
    let handoff: ShieldReviewHandoff
    let generatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        status: ShieldReviewStatus,
        riskLevel: ShieldReviewRiskLevel,
        parsedActions: [ShieldReviewParsedAction],
        programLabels: [String],
        signerCount: Int,
        writableCount: Int,
        unknownInstructionCount: Int,
        riskFlags: [ShieldReviewRiskFlag],
        simulation: ShieldReviewSimulationSummary,
        explanation: String,
        approvalRequirements: [ShieldReviewApprovalRequirement],
        unavailableReason: String? = nil,
        handoff: ShieldReviewHandoff,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.riskLevel = riskLevel
        self.parsedActions = parsedActions
        self.programLabels = programLabels
        self.signerCount = signerCount
        self.writableCount = writableCount
        self.unknownInstructionCount = unknownInstructionCount
        self.riskFlags = riskFlags
        self.simulation = simulation
        self.explanation = explanation
        self.approvalRequirements = approvalRequirements
        self.unavailableReason = unavailableReason
        self.handoff = handoff
        self.generatedAt = generatedAt
    }

    static func unavailable(title: String, reason: String, requirements: [ShieldReviewApprovalRequirement]) -> ShieldReviewSummary {
        let safeSummary = "\(title): Shield Review unavailable. Reason: \(reason). No raw transaction payload is persisted."
        return ShieldReviewSummary(
            title: title,
            status: .unavailable,
            riskLevel: .unknown,
            parsedActions: [],
            programLabels: [],
            signerCount: 0,
            writableCount: 0,
            unknownInstructionCount: 0,
            riskFlags: [
                ShieldReviewRiskFlag(kind: "review_unavailable", level: .unknown, message: reason)
            ],
            simulation: .notRun,
            explanation: "Shield Review could not decode this approval payload. Existing manual approval gates remain active.",
            approvalRequirements: requirements,
            unavailableReason: reason,
            handoff: ShieldReviewHandoff(
                safeSummary: safeSummary,
                temporaryRawPayloadAvailable: false,
                payloadAvailability: .summaryOnly,
                sourceFlow: .unknown,
                note: "Safe summary only."
            )
        )
    }
}
