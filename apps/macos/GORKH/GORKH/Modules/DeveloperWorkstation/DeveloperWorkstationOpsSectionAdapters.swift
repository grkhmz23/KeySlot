import SwiftUI

extension DeveloperWorkstationSectionContentView {
    var releaseManagerSection: some View {
        DeveloperWorkstationReleaseManagerView(
            activeProject: store.selectionState.activeProject,
            parsedIDL: store.idlState.parsedIDL,
            programEvidence: store.evidenceState.programEvidence,
            selectedCluster: store.selectionState.selectedCluster
        )
    }

    var programManagerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeveloperWorkstationProgramManagerView(
                selectedCluster: store.selectionState.selectedCluster,
                activeProject: store.selectionState.activeProject,
                toolchainSnapshot: store.toolchainState.toolchainSnapshot,
                developerWallet: store.localnetState.developerWallet,
                selectedTab: $store.programOpsState.programManagerTab,
                operation: $store.programOpsState.programOperation,
                programID: $store.rpcState.programID,
                artifactPath: $store.programOpsState.artifactPath,
                newAuthority: $store.programOpsState.newAuthority,
                destructivePhrase: $store.programOpsState.destructivePhrase,
                devnetCertificationPhrase: $store.programOpsState.devnetCertificationPhrase,
                programCommandPreview: store.programOpsState.programCommandPreview,
                programEvidence: store.evidenceState.programEvidence,
                localnetSmokePreflight: store.localnetState.localnetSmokePreflight,
                releaseStoreMessage: store.programOpsState.releaseStoreMessage,
                releaseRecords: store.programOpsState.releaseRecords,
                deploymentPreflightReport: store.programOpsState.deploymentPreflightReport,
                dateFormatter: dateFormatter,
                onPrepareCommandPreview: store.prepareProgramCommandPreview,
                onRunPreflight: store.runDeploymentPreflight,
                onCreateReleaseRecord: store.createReleaseRecordFromLatestEvidence,
                onPrepareLocalnetSmokePreflight: store.prepareLocalnetSmokePreflight,
                onCopyLatestReleaseJSON: store.copyLatestReleaseJSON,
                onCopyProgramID: store.copyReleaseProgramID,
                onCopySignature: store.copySignature,
                onOpenIDLDrift: store.openIDLDriftFromRelease,
                onOpenLogs: store.openLogsFromRelease
            )
            programEvidencePanel
        }
    }

    var programEvidencePanel: some View {
        DeveloperWorkstationProgramEvidencePanel(
            evidenceStoreMessage: store.evidenceState.evidenceStoreMessage,
            programEvidence: store.evidenceState.programEvidence,
            onCopyProgramID: store.copyEvidenceProgramID,
            onOpenIDLBrowser: store.openEvidenceIDLBrowser,
            onOpenLogs: store.openEvidenceLogs,
            onPersistD8Evidence: { store.persistEvidence(.d8LocalnetCertification) }
        )
    }

    var logsSection: some View {
        DeveloperWorkstationLogsView(
            programID: $store.rpcState.programID,
            logState: store.localnetState.logState,
            onToggleLogs: store.toggleLogs
        )
    }

    var localnetSection: some View {
        DeveloperWorkstationLocalnetView(
            selectedCluster: store.selectionState.selectedCluster,
            developerWallet: store.localnetState.developerWallet,
            localValidatorStatus: store.localnetState.localValidatorStatus,
            localValidatorResetPhrase: $store.localnetState.localValidatorResetPhrase,
            faucetAddress: $store.localnetState.faucetAddress,
            faucetAmount: $store.localnetState.faucetAmount,
            faucetStatus: store.localnetState.faucetStatus,
            onGenerateDeveloperWallet: store.generateDeveloperWallet,
            onDeleteDeveloperWallet: store.deleteDeveloperWallet,
            onRequestDevnetAirdrop: store.requestDevnetAirdrop
        )
    }
}
