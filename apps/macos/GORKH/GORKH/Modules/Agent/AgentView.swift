import SwiftUI

struct AgentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedSection: AgentSection = .overview
    @State private var statusSnapshot = ZerionStatusService().localSnapshot()
    @State private var policySnapshot = ZerionPolicyCenterSnapshot.unchecked
    @State private var auditTimeline = AgentAuditTimeline.initial
    @State private var proposals: [ZerionProposal] = [.sampleDraft]
    @State private var tinySwapProposals: [ZerionTinySwapProposal] = []
    @State private var agentProposals: [AgentProposal] = []
    @State private var chatMessages: [AgentChatMessage] = [
        AgentChatMessage(
            role: .assistant,
            text: "Ask me to summarize your portfolio, review yield or LP positions, draft a Wallet handoff, or prepare a policy-scoped Zerion tiny swap. I create proposals only."
        )
    ]
    @State private var chatDraft = ""
    @State private var lastIntent: AgentIntentClassification?
    @State private var toolResults: [AgentToolResult] = []
    @State private var agentMemory = AgentMemoryStore()
    @State private var conversationID = UUID()
    @State private var aiStatus = AgentAIStatus.localSafeMode(reason: "Hosted AI endpoint is not configured.")
    @State private var isAIResponding = false
    @State private var selectedTinySwap: ZerionTinySwapProposal?
    @State private var helpProbe = ZerionCLIHelpProbe.unchecked
    @State private var confirmationPhrase = ""
    @State private var unknownValueAcknowledged = false
    @State private var executionResult: ZerionExecutionResult?
    @State private var isRefreshing = false

    private let safetyPolicy = AgentSafetyPolicy.zerionA2
    private let statusService = ZerionStatusService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                safetyBanner
                sectionPicker

                switch selectedSection {
                case .overview:
                    AgentOverviewView(
                        snapshot: AgentOverviewSnapshot.from(status: statusSnapshot, draftProposalCount: proposals.count + tinySwapProposals.count + agentProposals.count),
                        safetyPolicy: safetyPolicy,
                        refreshAction: refreshStatus
                    )
                case .chat:
                    AgentChatView(
                        safetyPolicy: safetyPolicy,
                        messages: $chatMessages,
                        draftText: $chatDraft,
                        lastIntent: lastIntent,
                        proposals: agentProposals,
                        toolResults: toolResults,
                        memoryEntries: agentMemory.entries,
                        aiStatus: aiStatus,
                        isAIResponding: isAIResponding,
                        submitAction: submitChatMessage,
                        handoffAction: handoffAgentProposal
                    )
                case .zerionExecutor:
                    ZerionExecutorView(
                        snapshot: statusSnapshot,
                        isRefreshing: isRefreshing,
                        refreshAction: refreshStatus
                    )
                case .policyCenter:
                    ZerionPolicyCenterView(snapshot: policySnapshot)
                case .proposals:
                    ZerionProposalView(
                        legacyProposals: proposals,
                        tinySwapProposals: tinySwapProposals,
                        createSolanaProposal: createSolanaTinySwap,
                        createBaseProposal: createBaseTinySwap,
                        reviewProposal: reviewTinySwap
                    )
                    if let selectedTinySwap {
                        ZerionExecutionReviewView(
                            proposal: selectedTinySwap,
                            decision: reviewDecision(for: selectedTinySwap),
                            commandPlan: commandPlan(for: selectedTinySwap),
                            confirmationPhrase: confirmationPhrase,
                            unknownValueAcknowledged: unknownValueAcknowledged,
                            updateConfirmationPhrase: { confirmationPhrase = $0 },
                            updateUnknownValueAcknowledged: { unknownValueAcknowledged = $0 },
                            executeAction: executeSelectedTinySwap,
                            cancelAction: clearSelectedTinySwap
                        )
                    }
                    if let executionResult {
                        ZerionExecutionResultView(result: executionResult)
                    }
                case .audit:
                    AgentAuditView(timeline: auditTimeline)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("agent.root")
        .onAppear {
            appendAudit(.agentSectionViewed, "Agent section opened with A2 tiny-swap execution gate.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("Classify intents, prepare proposals, and hand off to Wallet or Zerion review.")
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Spacer()

            GorkhStatusChip(title: "Policy-gated proposals", systemImage: "lock.shield", color: GorkhColors.warning)
            GorkhStatusChip(title: "Main wallet disabled", systemImage: "wallet.pass", color: GorkhColors.accent)
        }
    }

    private var safetyBanner: some View {
        GorkhPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label(safetyPolicy.safetyBanner, systemImage: "shield.lefthalf.filled")
                    .font(.callout)
                    .foregroundStyle(GorkhColors.primaryText)
                HStack(spacing: 8) {
                    GorkhStatusChip(title: safetyPolicy.mainWalletAccess.label, systemImage: "xmark.shield", color: GorkhColors.warning)
                    GorkhStatusChip(title: "Chat proposals only", systemImage: "doc.badge.gearshape", color: GorkhColors.warning)
                    GorkhStatusChip(title: "No bridge / send / signing", systemImage: "lock", color: GorkhColors.warning)
                }
            }
        }
    }

    private var sectionPicker: some View {
        Picker("Agent section", selection: $selectedSection) {
            ForEach(AgentSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("agent.section.navigation")
    }

    private func refreshStatus() {
        guard isRefreshing == false else {
            return
        }
        isRefreshing = true
        let snapshot = statusService.refreshReadOnlyStatus()
        statusSnapshot = snapshot
        policySnapshot = statusService.loadPolicyCenter()
        helpProbe = statusService.loadHelpProbe()
        appendAudit(.zerionCLIStatusChecked, "Zerion read/status refresh completed.")
        appendAudit(.zerionAPIKeyStatusChecked, "Zerion API key status: \(snapshot.apiKeyStatus.label).")
        if snapshot.policyStatus == .loaded {
            appendAudit(.zerionPoliciesChecked, "Zerion policies/tokens checked.")
        }
        isRefreshing = false
    }

    private func submitChatMessage() {
        let input = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.isEmpty == false else {
            return
        }

        chatDraft = ""
        let userMessage = AgentChatMessage(role: .user, text: input)
        chatMessages.append(userMessage)
        appendAudit(.agentChatMessageReceived, "Agent chat message received.", details: ["length": "\(input.count)"])
        Task {
            await processChatInput(input)
        }
    }

    private func processChatInput(_ input: String) async {
        let classification = AgentIntentClassifier().classify(input)
        lastIntent = classification
        appendAudit(
            .agentIntentClassified,
            "Intent classified as \(classification.intentType.title).",
            details: ["intent": classification.intentType.rawValue]
        )

        let lane = AgentExecutionLaneRouter.route(
            classification,
            walletIsWatchOnly: walletManager.selectedProfile?.isWatchOnly == true
        )
        let aiResult = await hostedAIResult(for: input, classification: classification)

        if lane == .readOnlyAnalysis {
            let result = AgentDeFiOpportunityAnalyzer.analyze(
                classification: classification,
                portfolioSummary: walletManager.portfolioSummary,
                pnlSummary: walletManager.portfolioPnLSummary,
                auditEvents: walletManager.auditEvents
            )
            toolResults.insert(result, at: 0)
            agentMemory.remember(intent: classification, result: result)
            chatMessages.append(AgentChatMessage(role: .assistant, text: assistantMessage(localMessage: result.summary, aiResult: aiResult)))
            appendAudit(.agentReadOnlyAnalysisPerformed, result.title, details: ["intent": classification.intentType.rawValue])
            return
        }

        let decision = AgentPolicyEngine.evaluate(
            classification: classification,
            lane: lane,
            context: AgentPolicyContext(
                walletCanSign: walletManager.selectedProfile?.canSign == true,
                walletIsWatchOnly: walletManager.selectedProfile?.isWatchOnly == true,
                selectedNetwork: walletManager.selectedNetwork,
                zerionStatus: statusSnapshot
            )
        )
        appendAudit(
            .agentPolicyDecisionMade,
            "Agent policy decision: \(decision.status.rawValue).",
            details: ["lane": lane.rawValue, "intent": classification.intentType.rawValue]
        )

        let proposal = AgentProposalFactory.makeProposal(classification: classification, lane: lane, decision: decision)
        agentProposals.insert(proposal, at: 0)
        agentMemory.remember(intent: classification, proposal: proposal)

        switch decision.status {
        case .allowed:
            chatMessages.append(AgentChatMessage(role: .assistant, text: assistantMessage(localMessage: "\(proposal.title) is ready for destination-module review. I will not execute it from chat.", aiResult: aiResult)))
            appendAudit(.agentProposalCreated, proposal.title, details: ["handoff": proposal.handoffTarget.rawValue])
            if aiResult?.response.proposalDraft != nil {
                appendAudit(.aiProposalSuggestionAcceptedAsDraft, proposal.title, details: ["deterministicProposal": proposal.type.rawValue])
            }
        case .needsMoreInput:
            chatMessages.append(AgentChatMessage(role: .assistant, text: assistantMessage(localMessage: "I need more details before creating a reviewable proposal: \(decision.reasons.joined(separator: " "))", aiResult: aiResult)))
            appendAudit(.agentProposalCreated, "Agent created a missing-fields proposal.", details: ["intent": classification.intentType.rawValue])
        case .blocked:
            chatMessages.append(AgentChatMessage(role: .assistant, text: assistantMessage(localMessage: "Blocked by local policy: \(decision.reasons.joined(separator: " "))", aiResult: aiResult)))
            let kind: AgentAuditEvent.Kind = classification.intentType == .unsafe ? .agentUnsafeRequestBlocked : (classification.intentType == .unsupported ? .agentUnsupportedRequestBlocked : .agentProposalBlocked)
            appendAudit(kind, decision.reasons.first ?? "Agent proposal blocked.", details: ["intent": classification.intentType.rawValue])
        }
    }

    private func hostedAIResult(for input: String, classification: AgentIntentClassification) async -> AgentLLMProviderResult? {
        do {
            let redactedInput = try AgentRedactedContextBuilder.redactedUserMessageForAI(input)
            let context = try AgentRedactedContextBuilder.build(
                portfolioSummary: walletManager.portfolioSummary,
                pnlSummary: walletManager.portfolioPnLSummary,
                pusdCirculationSnapshot: walletManager.pusdCirculationSnapshot,
                auditEvents: walletManager.auditEvents,
                selectedProfile: walletManager.selectedProfile,
                selectedNetwork: walletManager.selectedNetwork,
                rpcSecurityStatus: walletManager.rpcProviderSecurityStatus,
                zerionStatus: statusSnapshot
            )
            let request = AgentLLMChatRequest(
                conversationID: conversationID,
                userMessage: redactedInput.message,
                deterministicIntent: classification,
                redactedContext: context,
                enabledLocalTools: AgentToolBoundary.enabledLocalTools,
                policyState: .current,
                safetyMode: "hosted_ai_advisory_policy_deterministic"
            )
            appendAudit(.hostedAIRequestPrepared, "Hosted AI request prepared.", details: ["redaction": redactedInput.status.rawValue])
            isAIResponding = true
            defer { isAIResponding = false }

            let configuration = AgentHostedAPIConfiguration()
            let provider: any AgentLLMProvider = configuration.baseURL == nil
                ? LocalDeterministicFallbackProvider(reason: "Hosted AI unavailable; using local safe mode.")
                : HostedDeepSeekProvider(client: AgentHostedAPIClient(configuration: configuration))
            let result = await provider.respond(to: request, redactionStatus: redactedInput.status)
            aiStatus = result.status

            if result.status.mode == .localSafeMode {
                appendAudit(.hostedAIUnavailableFallback, result.status.message)
                appendAudit(.localSafeModeUsed, "Local safe mode used for Agent response.")
            } else {
                appendAudit(.hostedAIResponseReceived, "Hosted AI response received.", details: ["state": result.status.providerState.rawValue])
            }
            for blocked in result.toolBoundaryDecision.blocked {
                appendAudit(.aiToolSuggestionBlocked, "AI tool suggestion blocked.", details: ["tool": blocked])
            }
            return result
        } catch {
            let reason = AgentSafetyRedactor.redact(String(describing: error))
            aiStatus = .hosted(
                state: .disabled,
                redactionStatus: .blocked,
                endpointHost: nil,
                responseStatus: "blocked",
                message: "Hosted AI request blocked by redaction."
            )
            appendAudit(.hostedAIRequestBlockedByRedaction, reason)
            return nil
        }
    }

    private func assistantMessage(localMessage: String, aiResult: AgentLLMProviderResult?) -> String {
        guard let aiResult else {
            return localMessage
        }
        let aiMessage = aiResult.response.assistantMessage
        if aiResult.status.mode == .localSafeMode {
            return "\(localMessage)\n\n\(aiMessage)"
        }
        return "\(aiMessage)\n\nPolicy result: \(localMessage)"
    }

    private func handoffAgentProposal(_ proposal: AgentProposal) {
        guard proposal.status == .readyForReview, proposal.isExpired == false else {
            appendAudit(.agentProposalBlocked, "Agent handoff blocked because proposal is not ready or has expired.")
            return
        }

        switch proposal.handoffTarget {
        case .walletSwap:
            markAgentProposalHandedOff(proposal)
            appState.requestWalletSection(.swap)
        case .walletSend:
            markAgentProposalHandedOff(proposal)
            appState.requestWalletSection(.send)
        case .walletPrivate:
            markAgentProposalHandedOff(proposal)
            appState.requestWalletSection(.privateWallet)
        case .walletPortfolio:
            markAgentProposalHandedOff(proposal)
            appState.requestWalletSection(.portfolio)
        case .zerionReview:
            guard let tinySwap = AgentProposalFactory.makeZerionTinySwap(from: proposal) else {
                appendAudit(.zerionProposalBlocked, "Agent Zerion handoff failed validation.")
                return
            }
            tinySwapProposals.insert(tinySwap, at: 0)
            selectedTinySwap = tinySwap
            selectedSection = .proposals
            confirmationPhrase = ""
            unknownValueAcknowledged = false
            executionResult = nil
            markAgentProposalHandedOff(proposal)
        case .none:
            appendAudit(.agentProposalBlocked, "Agent proposal has no destination handoff.")
        }
    }

    private func markAgentProposalHandedOff(_ proposal: AgentProposal) {
        if let index = agentProposals.firstIndex(where: { $0.id == proposal.id }) {
            agentProposals[index] = proposal.replacingStatus(.handedOff)
        }
        appendAudit(.agentProposalHandedOff, "\(proposal.title) handed off.", details: ["target": proposal.handoffTarget.rawValue])
    }

    private func createSolanaTinySwap() {
        let proposal = ZerionTinySwapProposal.sampleSolanaTinySwap
        tinySwapProposals.insert(proposal, at: 0)
        appendAudit(.zerionProposalDrafted, "Solana tiny swap proposal drafted.", details: ["chain": proposal.chain.rawValue])
    }

    private func createBaseTinySwap() {
        let proposal = ZerionTinySwapProposal.sampleBaseTinySwap
        tinySwapProposals.insert(proposal, at: 0)
        appendAudit(.zerionProposalDrafted, "Base tiny swap proposal drafted.", details: ["chain": proposal.chain.rawValue])
    }

    private func reviewTinySwap(_ proposal: ZerionTinySwapProposal) {
        selectedTinySwap = proposal
        confirmationPhrase = ""
        unknownValueAcknowledged = false
        executionResult = nil
        let decision = reviewDecision(for: proposal)
        if decision.canExecute == false {
            appendAudit(.zerionProposalBlocked, decision.blockingReasons.first ?? "Zerion proposal blocked by policy.")
        }
    }

    private func clearSelectedTinySwap() {
        selectedTinySwap = nil
        confirmationPhrase = ""
        unknownValueAcknowledged = false
    }

    private func reviewDecision(for proposal: ZerionTinySwapProposal) -> ZerionExecutionPolicyDecision {
        ZerionExecutionPolicy.validate(
            proposal: proposal,
            approval: ZerionExecutionApproval(
                proposalID: proposal.id,
                proposalFingerprint: proposal.fingerprint,
                confirmationPhrase: confirmationPhrase,
                unknownValueAcknowledged: unknownValueAcknowledged,
                approvedAt: Date()
            ),
            context: executionContext()
        )
    }

    private func commandPlan(for proposal: ZerionTinySwapProposal) -> ZerionSwapCommandPlan? {
        try? ZerionSwapCommandBuilder.build(proposal: proposal, helpProbe: helpProbe)
    }

    private func executeSelectedTinySwap() {
        guard let proposal = selectedTinySwap else {
            return
        }
        guard let executablePath = statusSnapshot.executablePath else {
            executionResult = .failed("Zerion CLI executable is unavailable.")
            appendAudit(.zerionExecutionFailed, "Zerion CLI executable is unavailable.")
            return
        }

        let approval = ZerionExecutionApproval(
            proposalID: proposal.id,
            proposalFingerprint: proposal.fingerprint,
            confirmationPhrase: confirmationPhrase,
            unknownValueAcknowledged: unknownValueAcknowledged,
            approvedAt: Date()
        )
        let context = executionContext()
        let decision = ZerionExecutionPolicy.validate(proposal: proposal, approval: approval, context: context)
        guard decision.canExecute else {
            executionResult = .failed(decision.blockingReasons.joined(separator: " "))
            appendAudit(.zerionPolicyValidationFailed, decision.blockingReasons.first ?? "Zerion policy validation failed.")
            return
        }

        appendAudit(.zerionProposalApproved, "Zerion tiny swap approved by exact phrase.", details: ["chain": proposal.chain.rawValue])
        appendAudit(.zerionExecutionStarted, "Zerion tiny swap execution started.", details: ["chain": proposal.chain.rawValue])
        let service = ZerionExecutionService(runner: ZerionCLICommandRunner(executablePath: executablePath))
        let result = service.executeTinySwap(proposal: proposal, approval: approval, context: context)
        executionResult = result
        appendAudit(result.status == .executed ? .zerionExecutionSucceeded : .zerionExecutionFailed, result.message)
    }

    private func executionContext() -> ZerionExecutionPolicyContext {
        ZerionExecutionPolicyContext(
            statusSnapshot: statusSnapshot,
            policySnapshot: policySnapshot,
            helpProbe: helpProbe,
            safetyPolicy: safetyPolicy
        )
    }

    private func appendAudit(_ kind: AgentAuditEvent.Kind, _ message: String, details: [String: String] = [:]) {
        var events = auditTimeline.events
        events.insert(AgentAuditEvent(kind: kind, message: message, details: details), at: 0)
        auditTimeline = AgentAuditTimeline(events: Array(events.prefix(50)))
    }
}
