import Foundation

struct DeveloperWorkstationTransactionDebuggerPresentation {
    let selectedCluster: WorkstationCluster
    let parsedIDL: WorkstationIDL?
    let currentProjectBrain: DeveloperProjectBrain?
    let report: TransactionDebugReport?
    let evidence: [TransactionDebugReport]
    let status: WorkstationDataStatus
    let message: String
    let isDebugging: Bool
    let isFetchingAccountDetails: Bool
    let dateFormatter: DateFormatter
}

struct DeveloperWorkstationTransactionDebuggerActions {
    let fetchDebug: () -> Void
    let fetchAccountDetails: () -> Void
    let openSecurityScanner: () -> Void
    let recordDebugReview: () -> Void
}

struct DeveloperWorkstationProgramManagerPresentation {
    let selectedCluster: WorkstationCluster
    let activeProject: WorkstationProject?
    let toolchainSnapshot: WorkstationToolchainSnapshot
    let developerWallet: DeveloperWalletMetadata
    let programCommandPreview: String
    let programEvidence: [WorkstationProgramOperationEvidence]
    let localnetSmokePreflight: WorkstationLocalnetSmokePreflight?
    let releaseStoreMessage: String
    let releaseRecords: [WorkstationDeploymentReleaseRecord]
    let deploymentPreflightReport: WorkstationDeploymentPreflightReport
    let dateFormatter: DateFormatter
}

struct DeveloperWorkstationProgramManagerActions {
    let prepareCommandPreview: () -> Void
    let runPreflight: () -> Void
    let createReleaseRecord: () -> Void
    let prepareLocalnetSmokePreflight: () -> Void
    let copyLatestReleaseJSON: () -> Void
    let copyProgramID: (String) -> Void
    let copySignature: (String) -> Void
    let openIDLDrift: () -> Void
    let openLogs: (String?) -> Void
}

struct DeveloperWorkstationTestWorkbenchPresentation {
    let activeProject: WorkstationProject?
    let toolchainSnapshot: WorkstationToolchainSnapshot
    let localValidatorStatus: WorkstationLocalValidatorStatus
    let testDetection: TestFrameworkDetection
    let testCommandPreview: WorkstationCommandPlan?
    let testWorkbenchMessage: String
    let isDetectingTests: Bool
    let isRunningTests: Bool
    let testRunHistory: [TestRunEvidence]
    let currentProjectBrain: DeveloperProjectBrain?
    let computeMeasurementCount: Int
    let computeLatestStatus: String
    let securityScanReport: SecurityScanReport?
    let generatedTestDrafts: [WorkstationGeneratedTestDraft]
    let testDraftMessage: String
    let dateFormatter: DateFormatter
}

struct DeveloperWorkstationTestWorkbenchActions {
    let refreshDetection: () -> Void
    let clearPreview: () -> Void
    let preparePreview: () -> Void
    let runApprovedTest: () -> Void
    let createDraft: (WorkstationMissingTestSuggestion) -> Void
}

struct DeveloperWorkstationLocalnetPresentation {
    let selectedCluster: WorkstationCluster
    let developerWallet: DeveloperWalletMetadata
    let localValidatorStatus: WorkstationLocalValidatorStatus
    let faucetStatus: String
}

struct DeveloperWorkstationLocalnetActions {
    let generateDeveloperWallet: () -> Void
    let deleteDeveloperWallet: () -> Void
    let requestDevnetAirdrop: (String, String, WorkstationRPCPermission) -> Void
}

struct DeveloperWorkstationPDAExplorerPresentation {
    let parsedIDL: WorkstationIDL?
    let activeProject: WorkstationProject?
    let programEvidence: [WorkstationProgramOperationEvidence]
    let currentProjectBrain: DeveloperProjectBrain?
    let manualPDAResult: WorkstationPDADerivationResult?
    let pdaAccountCheck: WorkstationPDAAccountCheck
    let isCheckingPDAAccount: Bool
    let idlDriftReport: WorkstationIDLDriftReport?
}

struct DeveloperWorkstationPDAExplorerActions {
    let deriveManualPDA: () -> Void
    let checkDerivedPDAAccount: () -> Void
    let recordPDAAnalysis: ([WorkstationPDAFinding]) -> Void
    let recordIDLDriftSummary: (WorkstationIDLDriftSummary) -> Void
}

struct DeveloperWorkstationFrontendAssistantPresentation {
    let activeProject: WorkstationProject?
    let currentProjectBrain: DeveloperProjectBrain?
    let parsedIDL: WorkstationIDL?
    let frontendReport: FrontendAssistantReport?
    let frontendDrafts: [FrontendGeneratedFileDraft]
    let frontendEvidence: [FrontendGenerationEvidence]
    let frontendMessage: String
}

struct DeveloperWorkstationFrontendAssistantActions {
    let inspectFrontend: () -> Void
    let copyDraftPreview: () -> Void
    let prepareDrafts: () -> Void
    let writeDrafts: () -> Void
    let revealGeneratedFile: (String) -> Void
}

struct DeveloperWorkstationAgentPresentation {
    let activeProject: WorkstationProject?
    let selectedCluster: WorkstationCluster
    let currentProjectBrain: DeveloperProjectBrain?
    let parsedIDL: WorkstationIDL?
    let transactionDebugReport: TransactionDebugReport?
    let message: String
    let history: [DeveloperAgentToolCallRecord]
    let isCallingTool: Bool
    let dateFormatter: DateFormatter
}

struct DeveloperWorkstationAgentActions {
    let runTool: () -> Void
    let recordBoundaryReview: () -> Void
}
