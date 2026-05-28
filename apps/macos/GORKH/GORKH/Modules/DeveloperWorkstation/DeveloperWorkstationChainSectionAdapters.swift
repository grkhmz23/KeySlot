import SwiftUI

extension DeveloperWorkstationSectionContentView {
    var transactionDebuggerSection: some View {
        DeveloperWorkstationTransactionDebuggerView(
            selectedCluster: store.selectionState.selectedCluster,
            parsedIDL: store.idlState.parsedIDL,
            currentProjectBrain: store.projectState.currentProjectBrain,
            report: store.rpcState.transactionDebugReport,
            evidence: store.rpcState.transactionDebugEvidence,
            status: store.rpcState.transactionDebugStatus,
            message: store.rpcState.transactionDebugMessage,
            isDebugging: store.rpcState.isTransactionDebugging,
            isFetchingAccountDetails: store.rpcState.isFetchingTransactionAccountDetails,
            dateFormatter: dateFormatter,
            signature: $store.rpcState.transactionDebugSignature,
            idlSelection: $store.rpcState.transactionDebugIDLSelection,
            pane: $store.rpcState.transactionDebugPane,
            logFilter: $store.rpcState.transactionDebugLogFilter,
            onFetchDebug: store.runTransactionDebug,
            onFetchAccountDetails: store.fetchTransactionDebugAccountDetails,
            onOpenSecurityScanner: { store.selectionState.selectedSection = .securityScanner },
            onRecordDebugReview: {
                store.appendActivity(.transactionDebugReviewed, "Transaction debugger report reviewed.", details: ["status": store.rpcState.transactionDebugReport?.status.rawValue ?? "missing"])
            }
        )
    }

    var pdaToolsView: DeveloperWorkstationPDAExplorerView {
        DeveloperWorkstationPDAExplorerView(
            parsedIDL: store.idlState.parsedIDL,
            activeProject: store.selectionState.activeProject,
            programEvidence: store.evidenceState.programEvidence,
            currentProjectBrain: store.projectState.currentProjectBrain,
            manualPDAResult: store.rpcState.manualPDAResult,
            pdaAccountCheck: store.rpcState.pdaAccountCheck,
            isCheckingPDAAccount: store.rpcState.isCheckingPDAAccount,
            idlDriftReport: store.idlState.idlDriftReport,
            programID: $store.rpcState.programID,
            accountAddress: $store.rpcState.accountAddress,
            pdaSeedInputs: $store.rpcState.pdaSeedInputs,
            idlDriftTargetPath: $store.idlState.idlDriftTargetPath,
            onDeriveManualPDA: store.deriveManualPDA,
            onCheckDerivedPDAAccount: store.checkDerivedPDAAccount,
            onRecordPDAAnalysis: { findings in
                store.appendActivity(.pdaAnalysisReviewed, "PDA analysis reviewed.", details: ["count": "\(findings.count)"])
            },
            onRecordIDLDriftSummary: { drift in
                store.appendActivity(.idlDriftReviewed, "IDL drift reviewed.", details: ["status": drift.status.rawValue])
            }
        )
    }

    var idlSection: some View {
        DeveloperWorkstationIDLBrowserView(
            idlText: $store.idlState.idlText,
            idlFilter: $store.idlState.idlFilter,
            idlDriftTargetPath: $store.idlState.idlDriftTargetPath,
            parsedIDL: store.idlState.parsedIDL,
            currentProjectBrain: store.projectState.currentProjectBrain,
            idlDriftReport: store.idlState.idlDriftReport,
            onParseIDL: store.parseIDL,
            onCompareIDLDrift: store.compareIDLDrift
        )
    }

    var accountDecoderSection: some View {
        DeveloperWorkstationAccountDecoderView(
            accountAddress: $store.rpcState.accountAddress,
            accountDataBase64: $store.rpcState.accountDataBase64,
            accountDecoderIDLAccountSelection: $store.idlState.accountDecoderIDLAccountSelection,
            parsedIDL: store.idlState.parsedIDL
        )
    }

    var rpcSection: some View {
        DeveloperWorkstationRPCPlaygroundView(
            rpcMethod: $store.rpcState.rpcMethod,
            rpcAddress: $store.rpcState.rpcAddress,
            rpcSignature: $store.rpcState.rpcSignature,
            encodedTransaction: $store.rpcState.encodedTransaction,
            selectedCluster: store.selectionState.selectedCluster
        )
    }

    var computeSection: some View {
        DeveloperWorkstationComputeLabView(
            computeInstructionName: $store.testSecurityState.computeInstructionName,
            computeMeasurements: store.testSecurityState.computeMeasurements,
            computeBaselines: store.testSecurityState.computeBaselines,
            computeRegressionMessage: store.testSecurityState.computeRegressionMessage,
            transactionDebugReport: store.rpcState.transactionDebugReport,
            latestTestRun: store.testSecurityState.testRunHistory.first,
            onStoreFromTransactionDebugger: store.storeComputeFromTransactionDebugger,
            onStoreFromLatestTest: store.storeComputeFromLatestTest,
            onSelectBaseline: store.selectComputeBaseline
        )
    }

    var computeRegressionPanel: some View {
        DeveloperWorkstationComputeRegressionPanel(
            computeInstructionName: $store.testSecurityState.computeInstructionName,
            computeMeasurements: store.testSecurityState.computeMeasurements,
            computeBaselines: store.testSecurityState.computeBaselines,
            computeRegressionMessage: store.testSecurityState.computeRegressionMessage,
            transactionDebugReport: store.rpcState.transactionDebugReport,
            latestTestRun: store.testSecurityState.testRunHistory.first,
            includeActions: true,
            onStoreFromTransactionDebugger: store.storeComputeFromTransactionDebugger,
            onStoreFromLatestTest: store.storeComputeFromLatestTest,
            onSelectBaseline: store.selectComputeBaseline
        )
    }
}
