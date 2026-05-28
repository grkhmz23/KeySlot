import Foundation

struct DeveloperWorkstationSelectionState {
    var selectedSection: DeveloperWorkstationSection = .overview
    var selectedCluster: WorkstationCluster = .localnet
    var activeProject: WorkstationProject?
}

struct DeveloperWorkstationProjectState {
    var projectBrainReports: [DeveloperProjectBrain] = []
    var currentProjectBrain: DeveloperProjectBrain?
    var projectBrainStatus: WorkstationDataStatus = .missing
    var projectBrainMessage = "Scan an imported project with the bounded conservative project scanner. This is not a full compiler/parser."
    var isProjectBrainScanning = false
    var projectPathInput = ""
    var zipPathInput = ""
    var gitURLInput = ""
    var trustPhrase = ""
}

struct DeveloperWorkstationToolchainState {
    var toolchainSnapshot: WorkstationToolchainSnapshot = .unchecked
    var toolchainPlans: [WorkstationToolchainInstallPlan] = []
    var anchorInstallPlan: WorkstationAnchorInstallPlan = WorkstationAnchorInstaller.plan(snapshot: .unchecked)
    var compatibilityMatrix: WorkstationCompatibilityMatrix = .unchecked
    var anchorStrategy: WorkstationAnchorStrategyDecision = WorkstationAnchorStrategySelector.select(matrix: .unchecked, avmPath: nil, rustupPath: nil)
    var avmUpdatePlan: WorkstationAVMUpdatePlan = WorkstationAVMModernizationPlanner.avmUpdatePlan(snapshot: .unchecked)
    var anchorBinaryPlan: WorkstationAnchorBinaryInstallPlan = WorkstationAVMModernizationPlanner.anchorBinaryInstallPlan(manifest: .d3Default)
}

struct DeveloperWorkstationIDLState {
    var idlText = ""
    var idlFilter = ""
    var parsedIDL: WorkstationIDL?
    var idlDriftTargetPath = ""
    var idlDriftReport: WorkstationIDLDriftReport?
    var accountDecoderIDLAccountSelection = "__auto"
}

struct DeveloperWorkstationRPCState {
    var transactionDebugSignature = ""
    var transactionDebugReport: TransactionDebugReport?
    var transactionDebugEvidence: [TransactionDebugReport] = []
    var transactionDebugStatus: WorkstationDataStatus = .missing
    var transactionDebugMessage = "Paste a public Solana signature and fetch read-only chain data. Root-cause suggestions are heuristic unless deterministic evidence is available."
    var transactionDebugPane: TransactionDebugPane = .summary
    var transactionDebugLogFilter = ""
    var transactionDebugIDLSelection = "__loaded"
    var isTransactionDebugging = false
    var isFetchingTransactionAccountDetails = false
    var pdaSeedInputs: [WorkstationPDASeedInput] = [WorkstationPDASeedInput(kind: .utf8String, value: "state")]
    var manualPDAResult: WorkstationPDADerivationResult?
    var pdaAccountCheck = WorkstationPDAAccountCheck(
        status: .notRun,
        address: nil,
        ownerProgram: nil,
        ownerLabel: nil,
        lamports: nil,
        executable: nil,
        dataLength: nil,
        decodedAccountType: nil,
        message: "Derive a PDA before checking account existence."
    )
    var isCheckingPDAAccount = false
    var accountAddress = ""
    var accountDataBase64 = ""
    var programID = ""
    var rpcMethod: WorkstationRPCMethod = .getHealth
    var rpcAddress = ""
    var rpcSignature = ""
    var encodedTransaction = ""
}

struct DeveloperWorkstationProgramOpsState {
    var programManagerTab: WorkstationProgramManagerTab = .buildDeploy
    var programCommandPlan: WorkstationCommandPlan?
    var releaseRecords: [WorkstationDeploymentReleaseRecord] = []
    var releaseStoreMessage = "Release records are redacted JSON records derived from real program-operation evidence."
    var deploymentPreflightReport: WorkstationDeploymentPreflightReport = .notRun
    var programOperation: WorkstationProgramOperation = .solanaProgramShow
    var artifactPath = ""
    var newAuthority = ""
    var destructivePhrase = ""
    var devnetCertificationPhrase = ""
    var programCommandPreview = "Prepare a command preview after toolchain, project, wallet, and cluster checks."
}

struct DeveloperWorkstationLocalnetState {
    var developerWallet: DeveloperWalletMetadata = .missing
    var localValidatorStatus: WorkstationLocalValidatorStatus = .unchecked
    var localValidatorResetPhrase = ""
    var localnetSmokePreflight: WorkstationLocalnetSmokePreflight?
    var faucetAddress = ""
    var faucetAmount = "0.5"
    var faucetStatus = "Airdrop requests are capped and limited to devnet/localnet."
    var logState = WorkstationLogStreamState.idle()
}

struct DeveloperWorkstationTestSecurityState {
    var testDetection: TestFrameworkDetection = .empty
    var selectedTestFramework: WorkstationTestFrameworkKind = .anchor
    var testCommandPreview: WorkstationCommandPlan?
    var testApprovalPhrase = ""
    var testWorkbenchMessage = "Refresh detection to inspect safe test frameworks. No command runs automatically."
    var isDetectingTests = false
    var isRunningTests = false
    var testRunHistory: [TestRunEvidence] = []
    var generatedTestDrafts: [WorkstationGeneratedTestDraft] = []
    var testDraftMessage = "Drafts are created only after an explicit click and are stored outside the project."
    var computeMeasurements: [WorkstationComputeMeasurement] = []
    var computeBaselines: [WorkstationComputeBaseline] = []
    var computeInstructionName = "unknown"
    var computeRegressionMessage = "Compute Regression uses real available logs/measurements only. No logs means no measurement."
    var securityScanReports: [SecurityScanReport] = []
    var securityScanReport: SecurityScanReport?
    var securityScanMessage = "Run conservative static checks for developer triage. This is not a formal audit and can miss vulnerabilities or produce false positives."
    var isSecurityScanning = false
    var securitySeverityFilter = "all"
    var securityStatusFilter = SecurityFindingStatus.open.rawValue
    var securityTextFilter = ""
    var securityDismissalReason = ""
}

struct DeveloperWorkstationAgentFrontendState {
    var frontendReport: FrontendAssistantReport?
    var frontendDrafts: [FrontendGeneratedFileDraft] = []
    var frontendEvidence: [FrontendGenerationEvidence] = []
    var frontendSelectedInstruction = ""
    var frontendDraftKind: FrontendGeneratedFileKind = .programConstants
    var frontendWriteApprovalPhrase = ""
    var frontendMessage = "Inspect an imported frontend before generating draft integration files."
    var developerAgentMode: DeveloperAgentMode = .readOnly
    var developerAgentToolID = "project.getBrain"
    var developerAgentPrompt = ""
    var developerAgentInstructionName = ""
    var developerAgentSignature = ""
    var developerAgentProgramID = ""
    var developerAgentSeed = "state"
    var developerAgentAccountAddress = ""
    var developerAgentAccountDataBase64 = ""
    var developerAgentIDLAccountName = ""
    var developerAgentRPCMethod: WorkstationRPCMethod = .getHealth
    var developerAgentOperation: WorkstationProgramOperation = .solanaProgramShow
    var developerAgentDraftKind: FrontendGeneratedFileKind = .programConstants
    var developerAgentApprovalPhrase = ""
    var developerAgentMessage = "AI provider not configured. Developer Agent is constrained by typed tools and approval gates; it is not autonomous."
    var developerAgentHistory: [DeveloperAgentToolCallRecord] = []
    var isDeveloperAgentCallingTool = false
    var developerAgentChatMessages: [AgentChatMessage] = []
    var developerAgentChatInput = ""
    var developerAgentActiveProposal: AgentProposalCardDisplay?
    var pendingWorkstationSection: DeveloperWorkstationSection?
}

struct DeveloperWorkstationEvidenceState {
    var programEvidence: [WorkstationProgramOperationEvidence] = [.d8LocalnetCertification, .d7LocalnetCertification]
    var evidenceStoreMessage = "Safe evidence is stored as redacted JSON under Application Support."
    var didRunTempCleanup = false
    var activity: [WorkstationActivityEvent] = [
        WorkstationActivityEvent(kind: .workstationOpened, message: "Developer Workstation opened.")
    ]
}
