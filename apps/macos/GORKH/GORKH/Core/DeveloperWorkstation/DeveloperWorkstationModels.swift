import Foundation

enum DeveloperWorkstationSection: String, CaseIterable, Identifiable, Codable {
    case overview
    case projects
    case toolchain
    case idlBrowser
    case programManager
    case logs
    case accountDecoder
    case rpcPlayground
    case computeLab
    case localnet
    case offlineSigning
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .projects:
            return "Projects"
        case .toolchain:
            return "Toolchain"
        case .idlBrowser:
            return "IDL Browser"
        case .programManager:
            return "Program Manager"
        case .logs:
            return "Logs"
        case .accountDecoder:
            return "Account Decoder"
        case .rpcPlayground:
            return "RPC Playground"
        case .computeLab:
            return "Compute Lab"
        case .localnet:
            return "Localnet"
        case .offlineSigning:
            return "Offline Signing"
        case .activity:
            return "Activity"
        }
    }
}

enum WorkstationDataStatus: String, Codable, Equatable {
    case ready
    case locked
    case missing
    case unavailable
    case error

    var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .locked:
            return "Locked"
        case .missing:
            return "Missing"
        case .unavailable:
            return "Unavailable"
        case .error:
            return "Error"
        }
    }
}

struct DeveloperWorkstationOverviewSnapshot: Codable, Equatable {
    let selectedCluster: WorkstationCluster
    let activeProjectName: String
    let projectTrustStatus: WorkstationProjectTrustStatus
    let toolchainReadyCount: Int
    let toolchainTotalCount: Int
    let developerWalletStatus: DeveloperWalletStatus
    let localValidatorStatus: WorkstationDataStatus
    let recentActivityCount: Int

    static let empty = DeveloperWorkstationOverviewSnapshot(
        selectedCluster: .localnet,
        activeProjectName: "No project",
        projectTrustStatus: .untrusted,
        toolchainReadyCount: 0,
        toolchainTotalCount: WorkstationToolchainComponent.allCases.count,
        developerWalletStatus: .missing,
        localValidatorStatus: .unavailable,
        recentActivityCount: 0
    )
}

enum WorkstationActivityKind: String, Codable, CaseIterable {
    case workstationOpened = "workstation_opened"
    case projectImported = "project_imported"
    case projectTrusted = "project_trusted"
    case toolchainChecked = "toolchain_checked"
    case toolchainInstallPlanCreated = "toolchain_install_plan_created"
    case toolchainChecksumVerified = "toolchain_checksum_verified"
    case toolchainChecksumFailed = "toolchain_checksum_failed"
    case devWalletGenerated = "dev_wallet_generated"
    case devWalletDeleted = "dev_wallet_deleted"
    case clusterSwitched = "cluster_switched"
    case idlLoaded = "idl_loaded"
    case accountDecoded = "account_decoded"
    case localValidatorStarted = "local_validator_started"
    case localValidatorStopped = "local_validator_stopped"
    case sampleSmokeStarted = "sample_smoke_started"
    case sampleSmokeSucceeded = "sample_smoke_succeeded"
    case sampleSmokeFailed = "sample_smoke_failed"
    case logsStarted = "logs_started"
    case logsStopped = "logs_stopped"
    case rpcCallPerformed = "rpc_call_performed"
    case airdropRequested = "airdrop_requested"
    case buildStarted = "build_started"
    case buildSucceeded = "build_succeeded"
    case buildFailed = "build_failed"
    case deployStarted = "deploy_started"
    case deploySucceeded = "deploy_succeeded"
    case deployFailed = "deploy_failed"
    case upgradeStarted = "upgrade_started"
    case upgradeSucceeded = "upgrade_succeeded"
    case upgradeFailed = "upgrade_failed"
    case closeStarted = "close_started"
    case closeSucceeded = "close_succeeded"
    case closeFailed = "close_failed"
    case authorityOperationAttempted = "authority_operation_attempted"
    case commandPreviewPrepared = "command_preview_prepared"
    case commandBlocked = "command_blocked"

    var title: String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct WorkstationActivityEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: WorkstationActivityKind
    let message: String
    let details: [String: String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: WorkstationActivityKind,
        message: String,
        details: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.message = AgentSafetyRedactor.redact(message)
        self.details = Redaction.safeDetails(details.mapValues { AgentSafetyRedactor.redact($0) })
        self.createdAt = createdAt
    }
}
