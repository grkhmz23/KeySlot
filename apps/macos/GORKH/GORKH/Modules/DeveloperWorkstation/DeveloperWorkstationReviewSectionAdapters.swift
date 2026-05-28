import SwiftUI

extension DeveloperWorkstationSectionContentView {
    var testWorkbenchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeveloperWorkstationTestWorkbenchView(
                activeProject: store.selectionState.activeProject,
                toolchainSnapshot: store.toolchainState.toolchainSnapshot,
                localValidatorStatus: store.localnetState.localValidatorStatus,
                testDetection: store.testSecurityState.testDetection,
                selectedTestFramework: $store.testSecurityState.selectedTestFramework,
                testCommandPreview: store.testSecurityState.testCommandPreview,
                testApprovalPhrase: $store.testSecurityState.testApprovalPhrase,
                testWorkbenchMessage: store.testSecurityState.testWorkbenchMessage,
                isDetectingTests: store.testSecurityState.isDetectingTests,
                isRunningTests: store.testSecurityState.isRunningTests,
                testRunHistory: store.testSecurityState.testRunHistory,
                currentProjectBrain: store.projectState.currentProjectBrain,
                computeMeasurementCount: store.testSecurityState.computeMeasurements.count,
                computeLatestStatus: ComputeRegressionService.rows(measurements: store.testSecurityState.computeMeasurements, baselines: store.testSecurityState.computeBaselines).first?.status.title ?? "No baseline",
                securityScanReport: store.testSecurityState.securityScanReport,
                generatedTestDrafts: store.testSecurityState.generatedTestDrafts,
                testDraftMessage: store.testSecurityState.testDraftMessage,
                dateFormatter: dateFormatter,
                onRefreshDetection: store.refreshTestDetection,
                onClearPreview: store.clearTestPreview,
                onPreparePreview: store.prepareTestCommandPreview,
                onRunApprovedTest: store.runApprovedTest,
                onCreateDraft: store.createTestDraft
            )
            computeRegressionPanel
        }
    }

    var securityScannerSection: some View {
        DeveloperWorkstationSecurityScannerView(
            activeProject: store.selectionState.activeProject,
            report: store.testSecurityState.securityScanReport,
            isScanning: store.testSecurityState.isSecurityScanning,
            message: store.testSecurityState.securityScanMessage,
            severityFilter: $store.testSecurityState.securitySeverityFilter,
            statusFilter: $store.testSecurityState.securityStatusFilter,
            textFilter: $store.testSecurityState.securityTextFilter,
            dismissalReason: $store.testSecurityState.securityDismissalReason,
            dateFormatter: dateFormatter,
            onRunScan: store.runSecurityScan,
            onDismissFinding: store.dismissSecurityFinding,
            onCopyReport: store.copySecurityScanJSON,
            onRecordReview: { report in
                store.appendActivity(.securityScanReviewed, "Developer Workstation security scan reviewed.", details: ["findings": "\(report.findings.count)"])
            }
        )
    }

    var frontendAssistantSection: some View {
        DeveloperWorkstationFrontendAssistantView(
            activeProject: store.selectionState.activeProject,
            currentProjectBrain: store.projectState.currentProjectBrain,
            parsedIDL: store.idlState.parsedIDL,
            frontendReport: store.agentFrontendState.frontendReport,
            frontendDrafts: store.agentFrontendState.frontendDrafts,
            frontendEvidence: store.agentFrontendState.frontendEvidence,
            frontendMessage: store.agentFrontendState.frontendMessage,
            selectedInstruction: $store.agentFrontendState.frontendSelectedInstruction,
            draftKind: $store.agentFrontendState.frontendDraftKind,
            writeApprovalPhrase: $store.agentFrontendState.frontendWriteApprovalPhrase,
            onInspectFrontend: store.inspectFrontend,
            onCopyDraftPreview: store.copyFrontendDrafts,
            onPrepareDrafts: store.prepareFrontendDrafts,
            onWriteDrafts: store.writeFrontendDrafts,
            onRevealGeneratedFile: store.revealGeneratedFrontendFile
        )
    }

    var workstationAgentSection: some View {
        DeveloperWorkstationAgentView(
            activeProject: store.selectionState.activeProject,
            selectedCluster: store.selectionState.selectedCluster,
            currentProjectBrain: store.projectState.currentProjectBrain,
            parsedIDL: store.idlState.parsedIDL,
            transactionDebugReport: store.rpcState.transactionDebugReport,
            mode: $store.agentFrontendState.developerAgentMode,
            toolID: $store.agentFrontendState.developerAgentToolID,
            prompt: $store.agentFrontendState.developerAgentPrompt,
            instructionName: $store.agentFrontendState.developerAgentInstructionName,
            signature: $store.agentFrontendState.developerAgentSignature,
            programID: $store.agentFrontendState.developerAgentProgramID,
            seed: $store.agentFrontendState.developerAgentSeed,
            accountAddress: $store.agentFrontendState.developerAgentAccountAddress,
            accountDataBase64: $store.agentFrontendState.developerAgentAccountDataBase64,
            idlAccountName: $store.agentFrontendState.developerAgentIDLAccountName,
            rpcMethod: $store.agentFrontendState.developerAgentRPCMethod,
            operation: $store.agentFrontendState.developerAgentOperation,
            draftKind: $store.agentFrontendState.developerAgentDraftKind,
            approvalPhrase: $store.agentFrontendState.developerAgentApprovalPhrase,
            message: store.agentFrontendState.developerAgentMessage,
            history: store.agentFrontendState.developerAgentHistory,
            isCallingTool: store.agentFrontendState.isDeveloperAgentCallingTool,
            dateFormatter: dateFormatter,
            onRunTool: store.runDeveloperAgentTool,
            onRecordBoundaryReview: {
                store.appendActivity(.workstationAgentReviewed, "Constrained Workstation Agent boundary reviewed.", details: [:])
            },
            chatMessages: store.agentFrontendState.developerAgentChatMessages,
            chatInput: $store.agentFrontendState.developerAgentChatInput,
            activeProposal: store.agentFrontendState.developerAgentActiveProposal,
            onSubmitChat: store.submitDeveloperAgentChat,
            onApproveProposal: store.approveDeveloperAgentProposal,
            onRejectProposal: store.rejectDeveloperAgentProposal
        )
    }
}
