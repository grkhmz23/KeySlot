import SwiftUI

extension DeveloperWorkstationSectionContentView {
    var overviewSection: some View {
        DeveloperWorkstationOverviewView(
            selectedCluster: store.selectionState.selectedCluster,
            activeProject: store.selectionState.activeProject,
            toolchainSnapshot: store.toolchainState.toolchainSnapshot,
            developerWallet: store.localnetState.developerWallet,
            localValidatorStatus: store.localnetState.localValidatorStatus,
            programEvidence: store.evidenceState.programEvidence,
            currentProjectBrain: store.projectState.currentProjectBrain,
            projectBrainStatus: store.projectState.projectBrainStatus,
            projectBrainMessage: store.projectState.projectBrainMessage,
            activity: store.evidenceState.activity,
            evidenceStoreMessage: store.evidenceState.evidenceStoreMessage,
            onSelectSection: { store.selectionState.selectedSection = $0 },
            onCopyProgramID: store.copyEvidenceProgramID,
            onOpenIDLBrowser: store.openEvidenceIDLBrowser,
            onOpenLogs: store.openEvidenceLogs,
            onPersistD8Evidence: { store.persistEvidence(.d8LocalnetCertification) }
        )
    }

    var projectBrainSection: some View {
        DeveloperWorkstationProjectBrainView(
            activeProject: store.selectionState.activeProject,
            report: store.projectState.currentProjectBrain,
            status: store.projectState.projectBrainStatus,
            message: store.projectState.projectBrainMessage,
            isScanning: store.projectState.isProjectBrainScanning,
            dateFormatter: dateFormatter,
            onRescan: store.scanProjectBrain,
            onOpenAccountDecoder: { store.selectionState.selectedSection = .accountDecoder },
            onValidatePDA: { candidate in
                if let programIdSource = candidate.programIdSource,
                   SolanaAddressValidator.isValidAddress(programIdSource) {
                    store.rpcState.programID = programIdSource
                }
                store.selectionState.selectedSection = .pdaExplorer
            },
            onOpenIDL: store.openProjectBrainIDL,
            onOpenSecurityScanner: { store.selectionState.selectedSection = .securityScanner }
        )
    }

    var projectsSection: some View {
        DeveloperWorkstationProjectsView(
            activeProject: store.selectionState.activeProject,
            currentProjectBrain: store.projectState.currentProjectBrain,
            projectPathInput: $store.projectState.projectPathInput,
            zipPathInput: $store.projectState.zipPathInput,
            gitURLInput: $store.projectState.gitURLInput,
            trustPhrase: $store.projectState.trustPhrase,
            onInspectFolder: store.inspectFolder,
            onInspectZip: store.inspectZip,
            onPrepareGitClone: store.prepareGitClone,
            onTrustProject: store.trustProject,
            onOpenProjectBrain: { store.selectionState.selectedSection = .projectBrain }
        )
    }

    var toolchainSection: some View {
        DeveloperWorkstationToolchainView(
            toolchainSnapshot: store.toolchainState.toolchainSnapshot,
            toolchainPlans: store.toolchainState.toolchainPlans,
            compatibilityMatrix: store.toolchainState.compatibilityMatrix,
            anchorInstallPlan: store.toolchainState.anchorInstallPlan,
            avmUpdatePlan: store.toolchainState.avmUpdatePlan,
            anchorBinaryPlan: store.toolchainState.anchorBinaryPlan,
            onRefreshToolchain: store.refreshToolchain,
            onRefreshCompatibility: store.refreshCompatibility
        )
    }

    var compatibilitySection: some View {
        DeveloperWorkstationCompatibilityView(
            compatibilityMatrix: store.toolchainState.compatibilityMatrix,
            anchorStrategy: store.toolchainState.anchorStrategy,
            avmUpdatePlan: store.toolchainState.avmUpdatePlan,
            anchorBinaryPlan: store.toolchainState.anchorBinaryPlan,
            onRefreshCompatibility: store.refreshCompatibility
        )
    }
}
