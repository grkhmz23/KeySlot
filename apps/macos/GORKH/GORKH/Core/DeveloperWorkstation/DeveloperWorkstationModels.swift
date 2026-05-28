import Foundation

enum DeveloperWorkstationSection: String, CaseIterable, Identifiable, Codable {
    case overview
    case projectBrain
    case transactionDebugger
    case pdaExplorer
    case idlDrift
    case fixtureStudio
    case testWorkbench
    case computeRegression
    case releaseManager
    case securityScanner
    case frontendAssistant
    case workstationAgent
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
        case .projectBrain:
            return "Project Brain"
        case .transactionDebugger:
            return "Transaction Debugger"
        case .pdaExplorer:
            return "PDA Explorer"
        case .idlDrift:
            return "IDL Drift"
        case .fixtureStudio:
            return "Fixture Studio"
        case .testWorkbench:
            return "Test Workbench"
        case .computeRegression:
            return "Compute Regression"
        case .releaseManager:
            return "Release Manager"
        case .securityScanner:
            return "Security Scanner"
        case .frontendAssistant:
            return "Frontend Assistant"
        case .workstationAgent:
            return "Workstation Agent"
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
        case .projectBrain:
            return "Explain imported project structure, IDLs, trust, evidence, and safe next steps."
        case .transactionDebugger:
            return "Decode public signatures or raw transaction fixtures for review-only debugging."
        case .pdaExplorer:
            return "Inspect IDL PDA metadata and detect mismatches when derivation inputs are concrete."
        case .idlDrift:
            return "Compare loaded IDL metadata against selected program ids and deploy evidence."
        case .fixtureStudio:
            return "Review localnet fixture and snapshot readiness without fake chain state."
        case .testWorkbench:
            return "Preview fixed test workflow readiness; no package scripts run automatically."
        case .computeRegression:
            return "Track compute evidence and simulation availability for regression review."
        case .releaseManager:
            return "Review localnet/devnet release readiness and mainnet lock status."
        case .securityScanner:
            return "Scan imported project metadata and policy state for Solana safety issues."
        case .frontendAssistant:
            return "Generate safe integration notes from the loaded IDL without writing app code."
        case .workstationAgent:
            return "Use constrained Workstation tools for read-only explanations and gated previews."
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
        case .projectBrain:
            return "brain.head.profile"
        case .transactionDebugger:
            return "ladybug"
        case .pdaExplorer:
            return "point.3.connected.trianglepath.dotted"
        case .idlDrift:
            return "arrow.triangle.2.circlepath"
        case .fixtureStudio:
            return "shippingbox"
        case .testWorkbench:
            return "testtube.2"
        case .computeRegression:
            return "chart.line.uptrend.xyaxis"
        case .releaseManager:
            return "checkmark.seal"
        case .securityScanner:
            return "shield.lefthalf.filled"
        case .frontendAssistant:
            return "curlybraces"
        case .workstationAgent:
            return "sparkles"
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
    case tempKeypairCleanup = "temp_keypair_cleanup"
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
    case projectBrainReviewed = "project_brain_reviewed"
    case projectBrainScanStarted = "project_brain_scan_started"
    case projectBrainScanned = "project_brain_scanned"
    case projectBrainScanFailed = "project_brain_scan_failed"
    case projectBrainEvidenceStored = "project_brain_evidence_stored"
    case transactionDebugReviewed = "transaction_debug_reviewed"
    case transactionDebugFetchStarted = "transaction_debug_fetch_started"
    case transactionDebugFetchSucceeded = "transaction_debug_fetch_succeeded"
    case transactionDebugFetchFailed = "transaction_debug_fetch_failed"
    case transactionDebugEvidenceStored = "transaction_debug_evidence_stored"
    case transactionDebugAccountDetailsFetched = "transaction_debug_account_details_fetched"
    case pdaAnalysisReviewed = "pda_analysis_reviewed"
    case pdaDerived = "pda_derived"
    case pdaAccountChecked = "pda_account_checked"
    case idlDriftReviewed = "idl_drift_reviewed"
    case idlDriftCompared = "idl_drift_compared"
    case testDetectionRefreshed = "test_detection_refreshed"
    case testCommandPrepared = "test_command_prepared"
    case testRunStarted = "test_run_started"
    case testRunSucceeded = "test_run_succeeded"
    case testRunFailed = "test_run_failed"
    case testRunBlocked = "test_run_blocked"
    case testEvidenceStored = "test_evidence_stored"
    case testDraftCreated = "test_draft_created"
    case computeMeasurementStored = "compute_measurement_stored"
    case computeBaselineSelected = "compute_baseline_selected"
    case releaseCreated = "release_created"
    case releaseFailed = "release_failed"
    case preflightFailed = "preflight_failed"
    case securityScanStarted = "security_scan_started"
    case securityScanCompleted = "security_scan_completed"
    case securityScanFailed = "security_scan_failed"
    case securityScanEvidenceStored = "security_scan_evidence_stored"
    case securityFindingDismissed = "security_finding_dismissed"
    case securityScanReviewed = "security_scan_reviewed"
    case frontendInspected = "frontend_inspected"
    case frontendDraftPreviewed = "frontend_draft_previewed"
    case frontendDraftWritten = "frontend_draft_written"
    case frontendDraftWriteBlocked = "frontend_draft_write_blocked"
    case frontendEvidenceStored = "frontend_evidence_stored"
    case workstationAgentReviewed = "workstation_agent_reviewed"
    case workstationAgentToolCalled = "workstation_agent_tool_called"
    case workstationAgentToolBlocked = "workstation_agent_tool_blocked"
    case workstationAgentApprovalRequested = "workstation_agent_approval_requested"
    case workstationAgentEvidenceStored = "workstation_agent_evidence_stored"

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
