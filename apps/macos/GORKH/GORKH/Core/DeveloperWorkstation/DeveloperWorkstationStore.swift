import Combine
import Foundation

struct DeveloperWorkstationStoreDependencies {
    var keyVault: any DeveloperKeyVaulting
    var evidenceStore: WorkstationProgramOperationEvidenceStore
    var deploymentReleaseStore: WorkstationDeploymentReleaseStore
    var projectBrainStore: DeveloperProjectBrainStore
    var transactionDebugService: TransactionDebugService
    var transactionDebugEvidenceStore: TransactionDebugEvidenceStore
    var pdaService: PDAService
    var testWorkbenchService: TestWorkbenchService
    var testRunEvidenceStore: TestRunEvidenceStore
    var computeRegressionStore: WorkstationComputeRegressionStore
    var securityScanStore: SecurityScanEvidenceStore
    var frontendEvidenceStore: FrontendAssistantEvidenceStore
    var developerAgentHistoryStore: DeveloperAgentToolHistoryStore
    var tempCleanupService: any DeveloperWorkstationTempCleaning
    var faucetService: any DeveloperFaucetServicing
    var projectBrainScanner: any DeveloperProjectBrainScanning
    var idlDriftService: any DeveloperIDLDriftComparing
    var securityScanner: any DeveloperSecurityScanning
    var frontendService: any DeveloperFrontendAssisting
    var releaseService: any DeveloperReleaseManaging

    @MainActor static var live: DeveloperWorkstationStoreDependencies {
        DeveloperWorkstationStoreDependencies(
            keyVault: KeychainDeveloperKeyVault(),
            evidenceStore: WorkstationProgramOperationEvidenceStore(),
            deploymentReleaseStore: WorkstationDeploymentReleaseStore(),
            projectBrainStore: DeveloperProjectBrainStore(),
            transactionDebugService: TransactionDebugService(),
            transactionDebugEvidenceStore: TransactionDebugEvidenceStore(),
            pdaService: PDAService(),
            testWorkbenchService: TestWorkbenchService(),
            testRunEvidenceStore: TestRunEvidenceStore(),
            computeRegressionStore: WorkstationComputeRegressionStore(),
            securityScanStore: SecurityScanEvidenceStore(),
            frontendEvidenceStore: FrontendAssistantEvidenceStore(),
            developerAgentHistoryStore: DeveloperAgentToolHistoryStore(),
            tempCleanupService: DeveloperWorkstationTempCleanupService(),
            faucetService: LiveDeveloperFaucetService(),
            projectBrainScanner: LiveDeveloperProjectBrainScanner(),
            idlDriftService: LiveDeveloperIDLDriftService(),
            securityScanner: LiveDeveloperSecurityScanner(),
            frontendService: LiveDeveloperFrontendAssistant(),
            releaseService: LiveDeveloperReleaseManager()
        )
    }
}

@MainActor
final class DeveloperWorkstationStore: ObservableObject {
    @Published var selectionState = DeveloperWorkstationSelectionState()
    @Published var projectState = DeveloperWorkstationProjectState()
    @Published var toolchainState = DeveloperWorkstationToolchainState()
    @Published var idlState = DeveloperWorkstationIDLState()
    @Published var rpcState = DeveloperWorkstationRPCState()
    @Published var programOpsState = DeveloperWorkstationProgramOpsState()
    @Published var localnetState = DeveloperWorkstationLocalnetState()
    @Published var testSecurityState = DeveloperWorkstationTestSecurityState()
    @Published var agentFrontendState = DeveloperWorkstationAgentFrontendState()
    @Published var evidenceState = DeveloperWorkstationEvidenceState()

    let dependencies: DeveloperWorkstationStoreDependencies

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        self.dependencies = .live
    }

    init(dependencies: DeveloperWorkstationStoreDependencies) {
        self.dependencies = dependencies
    }

    func startSession() {
        loadSession()
    }

    func loadSession() {
        localnetState.developerWallet = dependencies.keyVault.metadata() ?? .missing
        let stored = dependencies.evidenceStore.load()
        if !stored.isEmpty {
            evidenceState.programEvidence = stored
        }
        programOpsState.releaseRecords = dependencies.deploymentReleaseStore.load()
        projectState.projectBrainReports = dependencies.projectBrainStore.load()
        projectState.currentProjectBrain = projectState.projectBrainReports.first { $0.projectId == selectionState.activeProject?.id.uuidString } ?? projectState.projectBrainReports.first
        rpcState.transactionDebugEvidence = dependencies.transactionDebugEvidenceStore.load()
        rpcState.transactionDebugReport = rpcState.transactionDebugEvidence.first
        if rpcState.transactionDebugReport != nil {
            rpcState.transactionDebugStatus = .ready
            rpcState.transactionDebugMessage = "Loaded the latest redacted Transaction Debugger evidence."
        }
        if projectState.currentProjectBrain != nil {
            projectState.projectBrainStatus = .ready
            projectState.projectBrainMessage = "Loaded Project Brain report from redacted local evidence."
            if selectionState.activeProject == nil {
                projectState.projectPathInput = ""
            }
        }
        testSecurityState.testRunHistory = dependencies.testRunEvidenceStore.load()
        let computePayload = dependencies.computeRegressionStore.load()
        testSecurityState.computeMeasurements = computePayload.measurements
        testSecurityState.computeBaselines = computePayload.baselines
        testSecurityState.securityScanReports = dependencies.securityScanStore.load()
        testSecurityState.securityScanReport = testSecurityState.securityScanReports.first
        agentFrontendState.frontendEvidence = dependencies.frontendEvidenceStore.load()
        agentFrontendState.developerAgentHistory = dependencies.developerAgentHistoryStore.load()
        runTempArtifactCleanupIfNeeded()
    }

    func runTempArtifactCleanupIfNeeded() {
        guard !evidenceState.didRunTempCleanup else { return }
        evidenceState.didRunTempCleanup = true
        let result = dependencies.tempCleanupService.cleanup()
        evidenceState.activity.insert(
            WorkstationActivityEvent(
                kind: .tempKeypairCleanup,
                message: result.message,
                details: [
                    "scanned": "\(result.scannedCount)",
                    "removed": "\(result.removedCount)",
                    "failures": "\(result.failureCount)",
                    "directory": result.directorySummary
                ],
                createdAt: result.startedAt
            ),
            at: 0
        )
    }
}

extension String {
    var ifEmptyOptional: String? {
        isEmpty ? nil : self
    }
}
