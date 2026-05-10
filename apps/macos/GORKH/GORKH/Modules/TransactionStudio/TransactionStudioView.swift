import AppKit
import SwiftUI

enum TransactionStudioTab: String, CaseIterable, Identifiable {
    case decode
    case simulate
    case riskReview
    case explanation
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .decode:
            return "Decode"
        case .simulate:
            return "Simulate"
        case .riskReview:
            return "Risk Review"
        case .explanation:
            return "Explanation"
        case .history:
            return "History"
        }
    }
}

struct TransactionStudioView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedTab: TransactionStudioTab = .decode
    @State private var inputText = ""
    @State private var detectedInput: TransactionStudioInput?
    @State private var decodedTransaction: DecodedTransaction?
    @State private var addressSummary: TransactionStudioAddressSummary?
    @State private var simulation = TransactionStudioSimulationSummary.notRun
    @State private var riskReview = TransactionRiskReview.empty
    @State private var explanation = TransactionExplanationBuilder.build(decoded: nil, simulation: .notRun, risk: .empty)
    @State private var status: TransactionStudioStatus = .idle
    @State private var statusMessage = "Paste a Solana signature, raw transaction, or address to inspect it."
    @State private var history: [TransactionStudioHistoryEntry] = []
    @State private var isWorking = false

    private let rpcClient = SolanaRPCClient()
    private let simulationService = TransactionSimulationService()
    private let historyStore = TransactionStudioHistoryStore()
    private let auditLog = AuditLog()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            safetyBanner
            tabPicker

            HStack(alignment: .top, spacing: 14) {
                TransactionStudioInputView(
                    inputText: $inputText,
                    selectedNetwork: walletManager.selectedNetwork,
                    detectedInput: detectedInput,
                    status: status,
                    statusMessage: statusMessage,
                    isWorking: isWorking,
                    decodeAction: { Task { await decodeInput() } },
                    simulateAction: { Task { await simulateDecodedTransaction() } }
                )
                .frame(width: 340)

                Group {
                    switch selectedTab {
                    case .decode:
                        TransactionInstructionTimelineView(decoded: decodedTransaction, addressSummary: addressSummary)
                    case .simulate:
                        TransactionSimulationView(simulation: simulation)
                    case .riskReview:
                        TransactionRiskReviewView(review: riskReview)
                    case .explanation:
                        TransactionExplanationView(
                            explanation: explanation,
                            copyAction: copySummary,
                            sendToAgentAction: sendToAgent,
                            saveHistoryAction: saveHistory,
                            openActivityAction: openWalletActivity,
                            hasSignature: decodedTransaction?.fetchedSignature != nil
                        )
                    case .history:
                        TransactionStudioHistoryView(entries: history, clearAction: clearHistory)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            history = historyStore.load()
            record(.studioOpened, "Transaction Studio opened.")
        }
        .accessibilityIdentifier("transactionStudio.root")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Transaction Studio")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("Decode, simulate, explain, risk-review, and hand off Solana transaction findings.")
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            Spacer()
            GorkhStatusChip(title: "Read-only", systemImage: "eye", color: GorkhColors.accent)
            GorkhStatusChip(title: walletManager.selectedNetwork.displayName, systemImage: "network", color: walletManager.selectedNetwork.isMainnet ? GorkhColors.warning : GorkhColors.accent)
        }
    }

    private var safetyBanner: some View {
        GorkhPanel {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(GorkhColors.warning)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decode and simulate only. Transaction Studio v0.1 cannot sign, broadcast, or move funds.")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("There is no signing button, broadcast button, bundle composer, airdrop tool, or arbitrary RPC console here.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                }
            }
        }
    }

    private var tabPicker: some View {
        Picker("Transaction Studio tab", selection: $selectedTab) {
            ForEach(TransactionStudioTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("transactionStudio.tabs")
    }

    @MainActor
    private func decodeInput() async {
        guard isWorking == false else {
            return
        }
        isWorking = true
        defer { isWorking = false }
        record(.decodeAttempted, "Transaction Studio decode attempted.")
        status = .decoding
        statusMessage = "Decoding input..."
        decodedTransaction = nil
        addressSummary = nil
        simulation = .notRun

        do {
            let input = try TransactionStudioInputDetector.detect(inputText)
            detectedInput = input
            switch input.kind {
            case .rawTransaction:
                let decoded = try TransactionDecoder.decode(input: input, network: walletManager.selectedNetwork)
                decodedTransaction = decoded
                riskReview = TransactionRiskAnalyzer.review(decoded: decoded, simulation: simulation)
                explanation = TransactionExplanationBuilder.build(decoded: decoded, simulation: simulation, risk: riskReview)
                status = .decoded
                statusMessage = "Decoded \(decoded.instructions.count) instruction(s)."
                selectedTab = .decode
                record(.decodeSucceeded, "Raw transaction decoded.", details: ["fingerprint": decoded.fingerprint, "instructions": "\(decoded.instructions.count)"])
            case .signature:
                status = .fetching
                statusMessage = "Fetching transaction by signature..."
                if let fetched = try await rpcClient.getTransactionForStudio(signature: input.rawValue, network: walletManager.selectedNetwork) {
                    let decoded = try TransactionDecoder.decodeFetchedTransaction(
                        transactionBase64: fetched.transactionBase64,
                        signature: fetched.signature,
                        slot: fetched.slot,
                        blockTime: fetched.blockTime,
                        network: walletManager.selectedNetwork
                    )
                    decodedTransaction = decoded
                    riskReview = TransactionRiskAnalyzer.review(decoded: decoded, simulation: simulation)
                    explanation = TransactionExplanationBuilder.build(decoded: decoded, simulation: simulation, risk: riskReview)
                    status = .decoded
                    statusMessage = "Fetched and decoded signature \(input.safePreview)."
                    selectedTab = .decode
                    record(.decodeSucceeded, "Signature transaction decoded.", details: ["signature": input.safePreview, "fingerprint": decoded.fingerprint])
                } else {
                    status = .unavailable
                    statusMessage = "RPC returned no transaction for this signature."
                    record(.decodeFailed, "Signature not found.", details: ["signature": input.safePreview])
                }
            case .address:
                status = .fetching
                statusMessage = "Fetching public account summary..."
                if let summary = try await rpcClient.getAccountSummaryForStudio(address: input.rawValue, network: walletManager.selectedNetwork) {
                    addressSummary = summary
                    riskReview = TransactionRiskReview(level: summary.executable == true ? .medium : .low, flags: [], generatedAt: Date())
                    explanation = TransactionExplanationBuilder.build(decoded: nil, simulation: simulation, risk: riskReview, addressSummary: summary)
                    status = .decoded
                    statusMessage = "Fetched account summary."
                    selectedTab = .decode
                    record(.decodeSucceeded, "Address account summary fetched.", details: ["address": input.safePreview])
                } else {
                    status = .unavailable
                    statusMessage = "RPC returned no account for this address."
                    record(.decodeFailed, "Address account not found.", details: ["address": input.safePreview])
                }
            case .importHandoff, .unknown:
                throw TransactionStudioDecodeError.unsupportedInput
            }
        } catch {
            status = .failed
            statusMessage = error.localizedDescription
            riskReview = TransactionRiskAnalyzer.review(decoded: nil, simulation: .unavailable(error.localizedDescription))
            explanation = TransactionExplanationBuilder.build(decoded: nil, simulation: .unavailable(error.localizedDescription), risk: riskReview)
            record(.decodeFailed, "Transaction Studio decode failed.", details: ["error": error.localizedDescription])
        }
    }

    @MainActor
    private func simulateDecodedTransaction() async {
        guard let decodedTransaction, isWorking == false else {
            status = .unavailable
            statusMessage = "Decode a raw or fetched transaction before simulation."
            return
        }
        isWorking = true
        defer { isWorking = false }
        record(.simulationAttempted, "Transaction Studio simulation attempted.", details: ["fingerprint": decodedTransaction.fingerprint])
        status = .simulating
        statusMessage = "Simulating without signing or broadcasting..."
        simulation = await simulationService.simulate(decoded: decodedTransaction)
        riskReview = TransactionRiskAnalyzer.review(decoded: decodedTransaction, simulation: simulation)
        explanation = TransactionExplanationBuilder.build(decoded: decodedTransaction, simulation: simulation, risk: riskReview)
        selectedTab = .simulate
        switch simulation.status {
        case .success:
            status = .simulated
            statusMessage = "Simulation passed."
            record(.simulationSucceeded, "Transaction Studio simulation passed.", details: ["fingerprint": decodedTransaction.fingerprint])
        case .failed:
            status = .failed
            statusMessage = simulation.errorMessage ?? "Simulation failed."
            record(.simulationFailed, "Transaction Studio simulation failed.", details: ["fingerprint": decodedTransaction.fingerprint])
        case .unavailable, .notRun:
            status = .unavailable
            statusMessage = simulation.errorMessage ?? "Simulation unavailable."
            record(.simulationFailed, "Transaction Studio simulation unavailable.", details: ["fingerprint": decodedTransaction.fingerprint])
        }
        record(.riskReviewGenerated, "Transaction Studio risk review generated.", details: ["level": riskReview.level.rawValue])
        record(.explanationGenerated, "Transaction Studio explanation generated.")
    }

    private func copySummary() {
        let summary = explanation.summary
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        record(.handoffCreated, "Transaction Studio summary copied.")
    }

    private func sendToAgent() {
        appState.selectedModule = .agent
        record(.handoffCreated, "Transaction Studio finding handed to Agent.")
    }

    private func saveHistory() {
        let reference = decodedTransaction?.fetchedSignature ?? detectedInput?.safePreview ?? "local-summary"
        let entry = TransactionStudioHistoryEntry(
            inputKind: detectedInput?.kind ?? .unknown,
            publicReference: reference,
            summary: explanation.summary,
            riskLevel: riskReview.level,
            simulationStatus: simulation.status
        )
        historyStore.append(entry)
        history = historyStore.load()
        record(.handoffCreated, "Transaction Studio history entry saved.", details: ["risk": riskReview.level.rawValue])
    }

    private func clearHistory() {
        historyStore.clear()
        history = []
    }

    private func openWalletActivity() {
        appState.requestWalletSection(.activity)
        record(.handoffCreated, "Transaction Studio opened Wallet Activity.")
    }

    private func record(_ kind: TransactionStudioAuditEventKind, _ message: String, details: [String: String] = [:]) {
        auditLog.record(AuditEvent(
            kind: AuditEvent.Kind(rawValue: kind.rawValue) ?? .transactionStudioOpened,
            walletID: walletManager.selectedProfile?.id,
            network: walletManager.selectedNetwork,
            publicAddress: walletManager.selectedProfile?.publicAddress,
            message: message,
            details: details
        ))
    }
}
