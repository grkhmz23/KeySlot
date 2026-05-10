import Foundation

enum DeveloperWorkstationSection: String, CaseIterable, Identifiable, Codable {
    case overview
    case projects
    case toolchain
    case compatibility
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
        case .compatibility:
            return "Compatibility"
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

    var subtitle: String {
        switch self {
        case .overview:
            return "Status, quick actions, and recent program evidence."
        case .projects:
            return "Import, inspect, and explicitly trust developer projects."
        case .toolchain:
            return "Review managed, bundled, and system tool availability."
        case .compatibility:
            return "Check Anchor, Rust, AVM, and Solana compatibility."
        case .idlBrowser:
            return "Paste or load Anchor IDL JSON and inspect instructions."
        case .programManager:
            return "Preview gated localnet/devnet program operations."
        case .logs:
            return "View bounded program log streams and safe summaries."
        case .accountDecoder:
            return "Decode account data with an IDL when available."
        case .rpcPlayground:
            return "Use bounded read-only RPC forms and blocked unsafe methods."
        case .computeLab:
            return "Estimate compute from simulation-only transaction inputs."
        case .localnet:
            return "Manage the separate dev wallet, local validator, and faucet."
        case .offlineSigning:
            return "Review offline workflow foundations without signing or broadcast."
        case .activity:
            return "Inspect the redacted Workstation activity trail."
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "rectangle.grid.2x2"
        case .projects:
            return "folder"
        case .toolchain:
            return "wrench.and.screwdriver"
        case .compatibility:
            return "checklist.checked"
        case .idlBrowser:
            return "curlybraces.square"
        case .programManager:
            return "hammer"
        case .logs:
            return "text.alignleft"
        case .accountDecoder:
            return "doc.text.magnifyingglass"
        case .rpcPlayground:
            return "network"
        case .computeLab:
            return "cpu"
        case .localnet:
            return "server.rack"
        case .offlineSigning:
            return "externaldrive.badge.lock"
        case .activity:
            return "clock.arrow.circlepath"
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
    case compatibilityCheckStarted = "compatibility_check_started"
    case compatibilityCheckCompleted = "compatibility_check_completed"
    case compatibilityStrategyPrepared = "compatibility_strategy_prepared"
    case avmInstallPlanCreated = "avm_install_plan_created"
    case avmUpdatePlanCreated = "avm_update_plan_created"
    case avmUpdateStarted = "avm_update_started"
    case avmUpdateSucceeded = "avm_update_succeeded"
    case avmUpdateFailed = "avm_update_failed"
    case anchorBinaryInstallPlanCreated = "anchor_binary_install_plan_created"
    case avmInstallStarted = "avm_install_started"
    case avmInstallSucceeded = "avm_install_succeeded"
    case avmInstallFailed = "avm_install_failed"
    case anchorInstallStarted = "anchor_install_started"
    case anchorInstallSucceeded = "anchor_install_succeeded"
    case anchorInstallFailed = "anchor_install_failed"
    case toolchainChecksumVerified = "toolchain_checksum_verified"
    case toolchainChecksumFailed = "toolchain_checksum_failed"
    case devWalletGenerated = "dev_wallet_generated"
    case devWalletDeleted = "dev_wallet_deleted"
    case clusterSwitched = "cluster_switched"
    case idlLoaded = "idl_loaded"
    case accountDecoded = "account_decoded"
    case localValidatorStarted = "local_validator_started"
    case localValidatorStopped = "local_validator_stopped"
    case localValidatorStartRequested = "local_validator_start_requested"
    case localValidatorStartFailed = "local_validator_start_failed"
    case localValidatorStopRequested = "local_validator_stop_requested"
    case localValidatorStopFailed = "local_validator_stop_failed"
    case managedToolchainVerified = "managed_toolchain_verified"
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
    case programEvidenceStored = "program_evidence_stored"
    case localnetSmokeEvidenceViewed = "localnet_smoke_evidence_viewed"
    case devnetSmokeStarted = "devnet_smoke_started"
    case devnetSmokeSucceeded = "devnet_smoke_succeeded"
    case devnetSmokeFailed = "devnet_smoke_failed"
    case devWalletAirdropRequested = "dev_wallet_airdrop_requested"
    case devWalletAirdropSucceeded = "dev_wallet_airdrop_succeeded"
    case devWalletAirdropFailed = "dev_wallet_airdrop_failed"
    case programUpgradePreviewed = "program_upgrade_previewed"
    case programClosePreviewed = "program_close_previewed"
    case authorityTransferPreviewed = "authority_transfer_previewed"
    case authorityRevokePreviewed = "authority_revoke_previewed"
    case mainnetProgramOpBlocked = "mainnet_program_op_blocked"
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
