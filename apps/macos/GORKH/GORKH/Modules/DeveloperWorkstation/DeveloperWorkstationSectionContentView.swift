import SwiftUI

struct DeveloperWorkstationSectionContentView: View {
    @ObservedObject var store: DeveloperWorkstationStore
    let dateFormatter: DateFormatter

    var body: some View {
        switch store.selectionState.selectedSection {
        case .overview:
            overviewSection
        case .projectBrain:
            projectBrainSection
        case .transactionDebugger:
            transactionDebuggerSection
        case .pdaExplorer:
            pdaToolsView.pdaExplorer
        case .idlDrift:
            pdaToolsView.idlDrift
        case .fixtureStudio:
            pdaToolsView.fixtureStudio
        case .testWorkbench:
            testWorkbenchSection
        case .computeRegression:
            computeRegressionPanel
        case .releaseManager:
            releaseManagerSection
        case .securityScanner:
            securityScannerSection
        case .frontendAssistant:
            frontendAssistantSection
        case .workstationAgent:
            workstationAgentSection
        case .projects:
            projectsSection
        case .toolchain:
            toolchainSection
        case .compatibility:
            compatibilitySection
        case .idlBrowser:
            idlSection
        case .programManager:
            programManagerSection
        case .logs:
            logsSection
        case .accountDecoder:
            accountDecoderSection
        case .rpcPlayground:
            rpcSection
        case .computeLab:
            computeSection
        case .localnet:
            localnetSection
        case .offlineSigning:
            DeveloperWorkstationOfflineSigningView()
        case .activity:
            DeveloperWorkstationActivityView(activity: store.evidenceState.activity)
        }
    }
}
