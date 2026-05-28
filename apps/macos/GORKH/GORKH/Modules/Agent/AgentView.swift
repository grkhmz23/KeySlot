import SwiftUI

struct AgentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var walletManager: WalletManager
    @State private var selectedSection: AgentSection = .overview
    @State private var auditTimeline = AgentAuditTimeline.initial
    @State private var agentProposals: [AgentProposal] = []
    @State private var chatMessages: [AgentChatMessage] = [
        AgentChatMessage(
            role: .assistant,
            text: "Write what you want. Global Agent will create a proposal. You approve, sign, or reject proposals. Sensitive actions use existing app approval flows."
        )
    ]
    @State private var chatDraft = ""
    @State private var lastIntent: AgentIntentClassification?
    @State private var toolResults: [AgentToolResult] = []
    @State private var agentMemory = AgentMemoryStore()
    @State private var conversationID = UUID()
    @State private var aiStatus = AgentAIStatus.localSafeMode(reason: "Hosted AI endpoint is not configured.")
    @State private var isAIResponding = false
    @State private var globalAgentProposals: [GlobalAgentProposal] = []

    private let safetyPolicy = AgentSafetyPolicy.baseline

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                agentBoundaryBanner
                safetyBanner
                sectionPicker

                switch selectedSection {
                case .overview:
                    AgentOverviewView(
                        snapshot: AgentOverviewSnapshot(
                            walletContextAvailable: true,
                            draftProposalCount: agentProposals.count,
                            mainWalletAccess: .disabled,
                            updatedAt: Date()
                        ),
                        safetyPolicy: safetyPolicy
                    )
                case .chat:
                    capabilityPanel
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
                        handoffAction: handoffAgentProposal,
                        clearMemoryAction: clearAgentMemory
                    )
                    proposalCardsPanel
                case .proposals:
                    AgentAuditView(timeline: auditTimeline)
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
            consumePendingAgentMessageIfNeeded()
        }
        .onChange(of: appState.pendingAgentMessage) {
            consumePendingAgentMessageIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("Classify intents, prepare proposals, and hand off to Wallet review.")
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Spacer()

            GorkhStatusChip(title: "Policy-gated proposals", systemImage: "lock.shield", color: GorkhColors.warning)
            GorkhStatusChip(title: "Main wallet disabled", systemImage: "wallet.pass", color: GorkhColors.accent)
        }
    }

    private var agentBoundaryBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            GorkhPanel("Agent Scope") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Global Agent is the general KeySlot assistant.")
                    Text("Sensitive execution requires app policy and approval flows.")
                    Text("It cannot reveal private keys or seed phrases.")
                    Text("Developer Workstation command execution belongs in Developer Workstation.")
                }
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            }
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

    private var capabilityPanel: some View {
        GorkhPanel("What Global Agent can do") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Global Agent creates explanations and proposals.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("Sensitive actions require app approval flows.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text("Global Agent does not reveal private keys or seed phrases.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text("Global Agent does not execute arbitrary shell or raw terminal commands.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text("Solana build/deploy/debug tooling belongs in Developer Workstation.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)

                Divider().overlay(GorkhColors.border)

                capabilityGroup(title: "Available", status: .available, color: GorkhColors.success)
                capabilityGroup(title: "Proposal Only", status: .proposalOnly, color: GorkhColors.warning)
                capabilityGroup(title: "Handoff Only", status: .handoffOnly, color: GorkhColors.accent)
                capabilityGroup(title: "Blocked", status: .blocked, color: GorkhColors.danger)
            }
        }
    }

    private func capabilityGroup(title: String, status: GlobalAgentCapabilityStatus, color: Color) -> some View {
        let caps = GlobalAgentCapabilityRegistry.capabilities(withStatus: status)
        guard caps.isEmpty == false else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 6)], alignment: .leading, spacing: 4) {
                    ForEach(caps) { cap in
                        GorkhStatusChip(title: cap.title, systemImage: "circle.fill", color: color)
                    }
                }
            }
        )
    }

    private var proposalCardsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if globalAgentProposals.isEmpty == false {
                Text("Proposals")
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
                ForEach(globalAgentProposals) { proposal in
                    globalAgentProposalCard(proposal)
                }
            }
        }
    }

    private func globalAgentProposalCard(_ proposal: GlobalAgentProposal) -> some View {
        GorkhPanel(proposal.title) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    GorkhStatusChip(
                        title: proposal.kind.rawValue,
                        systemImage: "doc.text",
                        color: proposalColor(for: proposal)
                    )
                    if proposal.requiresApproval {
                        GorkhStatusChip(title: "Approval required", systemImage: "checkmark.shield", color: GorkhColors.warning)
                    }
                    if proposal.blockedReason != nil {
                        GorkhStatusChip(title: "Blocked", systemImage: "xmark.octagon", color: GorkhColors.danger)
                    }
                    if let target = proposal.handoffTarget {
                        GorkhStatusChip(title: "Handoff: \(target.rawValue)", systemImage: "arrow.right.circle", color: GorkhColors.accent)
                    }
                }

                Text(proposal.summary)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.primaryText)

                if proposal.details.isEmpty == false {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(proposal.details, id: \.self) { detail in
                            Text("• \(detail)")
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    }
                }

                HStack(spacing: 12) {
                    if let handoffTarget = proposal.handoffTarget {
                        Button(action: {
                            handoffGlobalAgentProposal(proposal)
                        }) {
                            Label(
                                "Open Developer Workstation",
                                systemImage: "arrow.right.circle.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GorkhColors.accent)
                        .disabled(proposal.blockedReason != nil)
                    } else if proposal.blockedReason == nil {
                        Button(action: {
                            approveGlobalAgentProposal(proposal)
                        }) {
                            Label(primaryButtonTitle(for: proposal), systemImage: "eye.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GorkhColors.warning)
                    }

                    Button(action: {
                        rejectGlobalAgentProposal(proposal)
                    }) {
                        Label("Reject", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(GorkhColors.danger)

                    Spacer()
                }
            }
        }
    }

    private func proposalColor(for proposal: GlobalAgentProposal) -> Color {
        if proposal.blockedReason != nil {
            return GorkhColors.danger
        }
        switch proposal.kind {
        case .sendPaymentDraft, .swapDraft:
            return GorkhColors.warning
        case .developerWorkstationHandoff:
            return GorkhColors.accent
        case .unsupported:
            return GorkhColors.danger
        default:
            return GorkhColors.success
        }
    }

    private func handoffGlobalAgentProposal(_ proposal: GlobalAgentProposal) {
        guard let target = proposal.handoffTarget else { return }
        switch target {
        case .developerWorkstation:
            appState.selectedModule = .developerWorkstation
            appendAudit(.handoffOpened, "Global Agent handoff to Developer Workstation.", details: ["proposal": proposal.kind.rawValue])
        default:
            break
        }
    }

    private func rejectGlobalAgentProposal(_ proposal: GlobalAgentProposal) {
        globalAgentProposals.removeAll { $0.id == proposal.id }
        chatMessages.append(AgentChatMessage(
            role: .system,
            text: "Proposal '\(proposal.title)' rejected. Nothing was executed."
        ))
        appendAudit(.agentProposalBlocked, "Global proposal rejected by user: \(proposal.title)")
    }

    private func primaryButtonTitle(for proposal: GlobalAgentProposal) -> String {
        switch proposal.kind {
        case .sendPaymentDraft: return "Review in Wallet"
        case .receiveRequestDraft: return "Open Wallet"
        case .depositDraft: return "Open Wallet"
        case .swapDraft: return "Review Swap"
        case .transactionReview: return "Open Transaction Studio"
        case .developerWorkstationHandoff: return "Open Developer Workstation"
        case .unsupported: return "Blocked"
        }
    }

    private func approveGlobalAgentProposal(_ proposal: GlobalAgentProposal) {
        var resultMessage = ""
        switch proposal.kind {
        case .sendPaymentDraft:
            if let prefill = proposal.sendPrefill,
               prefill.amount != nil || prefill.recipient != nil {
                walletManager.pendingSendDraft = PendingSendDraft(
                    amount: prefill.amount ?? "",
                    recipient: prefill.recipient ?? "",
                    token: prefill.token
                )
                resultMessage = "Wallet send review opened with prefilled details. Review and confirm before sending."
            } else {
                resultMessage = "Wallet send review opened. Review the payment details and approve in the Wallet send flow."
            }
            appState.requestWalletSection(.send)
            appendAudit(.handoffOpened, "Global Agent opened Wallet send review.", details: ["proposal": proposal.kind.rawValue])
        case .receiveRequestDraft:
            appState.requestWalletSection(.overview)
            resultMessage = "Wallet overview opened. Copy your receive address from the Wallet overview."
            appendAudit(.handoffOpened, "Global Agent opened Wallet overview for receive.", details: ["proposal": proposal.kind.rawValue])
        case .depositDraft:
            appState.requestWalletSection(.overview)
            resultMessage = "Wallet overview opened. Use the deposit flow in the Wallet to add funds safely."
            appendAudit(.handoffOpened, "Global Agent opened Wallet overview for deposit.", details: ["proposal": proposal.kind.rawValue])
        case .swapDraft:
            appState.requestWalletSection(.swap)
            resultMessage = "Wallet swap review opened. Review the swap details and approve in the Wallet swap flow."
            appendAudit(.handoffOpened, "Global Agent opened Wallet swap review.", details: ["proposal": proposal.kind.rawValue])
        case .transactionReview:
            appState.requestTransactionStudioSummary(proposal.summary)
            resultMessage = "Transaction Studio opened. Review the transaction details safely without signing or broadcasting."
            appendAudit(.handoffOpened, "Global Agent opened Transaction Studio review.", details: ["proposal": proposal.kind.rawValue])
        case .developerWorkstationHandoff:
            appState.requestDeveloperWorkstationSection(.workstationAgent)
            resultMessage = "Developer Workstation opened. Review the proposal there; no command was executed."
            appendAudit(.handoffOpened, "Global Agent handoff to Developer Workstation.", details: ["proposal": proposal.kind.rawValue])
        case .unsupported:
            resultMessage = "This proposal is blocked and cannot be opened."
            appendAudit(.agentProposalBlocked, "Global proposal is blocked: \(proposal.title)")
        }
        globalAgentProposals.removeAll { $0.id == proposal.id }
        chatMessages.append(AgentChatMessage(role: .system, text: resultMessage))
    }

    private func submitChatMessage() {
        let input = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.isEmpty == false else {
            return
        }

        chatDraft = ""
        
        // Check for forbidden content before processing
        if let forbidden = AgentRedactedContextBuilder.firstForbiddenMatch(in: input) {
            let userMessage = AgentChatMessage(role: .user, text: "[REDACTED: sensitive content detected]")
            chatMessages.append(userMessage)
            chatMessages.append(AgentChatMessage(
                role: .assistant,
                text: "For your safety, do not type recovery phrases into chat. Use Wallet → Create or Restore and enter them only in the secure wallet screen."
            ))
            appendAudit(.agentUnsafeRequestBlocked, "Agent blocked sensitive input: \(forbidden)", details: ["reason": "secret_material_detected"])
            return
        }
        
        let userMessage = AgentChatMessage(role: .user, text: input)
        chatMessages.append(userMessage)
        appendAudit(.agentChatMessageReceived, "Agent chat message received.", details: ["length": "\(input.count)"])
        Task {
            await processChatInput(input)
        }
    }

    private func processChatInput(_ input: String) async {
        let fullAppIntent = AgentFullAppIntentClassifier.classify(input)
        let classification = fullAppIntent.classification
        lastIntent = classification
        appendAudit(
            .fullAppIntentClassified,
            "Full-app intent classified as \(classification.intentType.title).",
            details: ["area": fullAppIntent.appArea.rawValue, "intent": classification.intentType.rawValue]
        )
        appendAudit(
            .agentIntentClassified,
            "Intent classified as \(classification.intentType.title).",
            details: ["intent": classification.intentType.rawValue]
        )

        // Deterministic Global Agent intent mapper (no LLM, no execution)
        if let mappedProposal = GlobalAgentIntentMapper.map(input) {
            globalAgentProposals.insert(mappedProposal, at: 0)
            let assistantText: String
            if let blockedReason = mappedProposal.blockedReason {
                assistantText = "Blocked: \(blockedReason)"
                appendAudit(.agentProposalBlocked, blockedReason, details: ["mapper": mappedProposal.kind.rawValue])
            } else if let handoffTarget = mappedProposal.handoffTarget {
                assistantText = "This request belongs in \(handoffTarget.rawValue). Review the proposal card and tap the handoff button."
                appendAudit(.agentProposalCreated, "Mapped to \(handoffTarget.rawValue) handoff.", details: ["mapper": mappedProposal.kind.rawValue])
            } else {
                assistantText = "I created a \(mappedProposal.title) proposal. Review the card below and proceed through the app approval flow."
                appendAudit(.agentProposalCreated, mappedProposal.title, details: ["mapper": mappedProposal.kind.rawValue])
            }
            chatMessages.append(AgentChatMessage(role: .assistant, text: assistantText))
            return
        }

        let lane = AgentExecutionLaneRouter.route(
            classification,
            walletIsWatchOnly: walletManager.selectedProfile?.isWatchOnly == true
        )
        let aiResult = await hostedAIResult(for: input, classification: classification)

        if lane == .readOnlyAnalysis {
            let result = AgentToolExecutor.execute(
                classification: classification,
                context: toolExecutionContext()
            ) ?? readOnlyFallbackResult(for: classification)
            toolResults.insert(result, at: 0)
            agentMemory.remember(intent: classification, result: result)
            chatMessages.append(AgentChatMessage(role: .assistant, text: assistantMessage(localMessage: result.summary, aiResult: aiResult)))
            appendAudit(.agentReadOnlyAnalysisPerformed, result.title, details: ["intent": classification.intentType.rawValue])
            if let toolID = fullAppIntent.defaultToolID {
                appendAudit(.localToolCalled, "Local read-only tool called.", details: ["tool": toolID.rawValue])
            } else {
                appendAudit(.localToolBlocked, "No local tool was required for this read-only intent.", details: ["intent": classification.intentType.rawValue])
            }
            return
        }

        let decision = AgentPolicyEngine.evaluate(
            classification: classification,
            lane: lane,
            context: AgentPolicyContext(
                walletCanSign: walletManager.selectedProfile?.canSign == true,
                walletIsWatchOnly: walletManager.selectedProfile?.isWatchOnly == true,
                selectedNetwork: walletManager.selectedNetwork
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
        appendAudit(.proposalHydrated, "Agent proposal hydrated from deterministic policy.", details: ["type": proposal.type.rawValue, "handoff": proposal.handoffTarget.rawValue])

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
            let hydrated = try AgentContextHydrator.hydrate(
                portfolioSummary: walletManager.portfolioSummary,
                pnlSummary: walletManager.portfolioPnLSummary,
                pusdCirculationSnapshot: walletManager.pusdCirculationSnapshot,
                auditEvents: walletManager.auditEvents,
                selectedProfile: walletManager.selectedProfile,
                selectedNetwork: walletManager.selectedNetwork,
                rpcSecurityStatus: walletManager.rpcProviderSecurityStatus,
            )
            let request = AgentLLMChatRequest(
                conversationID: conversationID,
                userMessage: redactedInput.message,
                deterministicIntent: classification,
                redactedContext: hydrated.redactedContext,
                enabledLocalTools: AgentToolBoundary.enabledLocalTools,
                policyState: .current,
                safetyMode: "hosted_ai_advisory_policy_deterministic"
            )
            try AgentHostedAPIValidator.validateOutbound(AgentHostedChatRequest(llmRequest: request))
            appendAudit(.hostedBackendContractValidated, "Hosted Agent API contract validated locally.", details: ["version": AgentHostedAPIContract.version])
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
                appendAudit(.hostedAIFallback, result.status.message)
                appendAudit(.localSafeModeUsed, "Local safe mode used for Agent response.")
                if result.status.fallbackReason?.lowercased().contains("authentication failed") == true {
                    appendAudit(.hostedAuthFailure, "Hosted AI authentication failed.")
                }
                if result.status.fallbackReason?.lowercased().contains("timed out") == true {
                    appendAudit(.hostedTimeoutFallback, "Hosted AI timeout fallback.")
                }
            } else {
                var details = ["state": result.status.providerState.rawValue]
                if let requestID = result.status.lastRequestID {
                    details["requestId"] = requestID
                }
                appendAudit(.hostedAIResponseReceived, "Hosted AI response received.", details: details)
                appendAudit(.hostedAIUsed, "Hosted AI enriched Agent response.", details: details)
            }
            for blocked in result.toolBoundaryDecision.blocked {
                appendAudit(.aiToolSuggestionBlocked, "AI tool suggestion blocked.", details: ["tool": blocked])
                appendAudit(.unsafeBackendSuggestionBlocked, "Unsafe backend suggestion blocked.", details: ["tool": blocked])
                appendAudit(.hostedUnsafeResponseBlocked, "Hosted unsafe response blocked.", details: ["tool": blocked])
            }
            if result.response.safetyWarnings.contains(where: { $0.lowercased().contains("execution approval was ignored") }) {
                appendAudit(.malformedBackendResponseIgnored, "Backend execution approval was ignored.")
                appendAudit(.hostedMalformedResponseBlocked, "Hosted malformed response blocked.")
            }
            return result
        } catch {
            let reason = AgentSafetyRedactor.redact(String(describing: error))
            aiStatus = .hosted(
                state: .disabled,
                redactionStatus: .blocked,
                endpointHost: AgentHostedAPIConfiguration().endpointHost,
                authStatus: AgentHostedAPIConfiguration().apiKeyStatus,
                responseStatus: "blocked",
                message: "Hosted AI request blocked by redaction.",
                backendContractVersion: AgentHostedAPIContract.version
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

        let instruction = AgentHandoffCoordinator.instruction(for: proposal)
        switch proposal.handoffTarget {
        case .walletSwap:
            markAgentProposalHandedOff(proposal)
            appendAudit(.handoffOpened, instruction.title, details: ["target": proposal.handoffTarget.rawValue])
            appState.requestWalletSection(.swap)
        case .walletSend:
            markAgentProposalHandedOff(proposal)
            appendAudit(.handoffOpened, instruction.title, details: ["target": proposal.handoffTarget.rawValue])
            appState.requestWalletSection(.send)
        case .walletOverview, .walletReceive:
            markAgentProposalHandedOff(proposal)
            appendAudit(.handoffOpened, instruction.title, details: ["target": proposal.handoffTarget.rawValue])
            appState.requestWalletSection(.overview)
        case .walletPortfolio,
             .portfolioAssets,
             .portfolioWallets,
             .portfolioPUSD,
             .portfolioStake,
             .portfolioLending,
             .portfolioLiquidity,
             .portfolioYield,
             .portfolioPnL,
             .portfolioHistory:
            markAgentProposalHandedOff(proposal)
            appendAudit(.handoffOpened, instruction.title, details: ["target": proposal.handoffTarget.rawValue])
            appState.requestWalletSection(.portfolio)
        case .walletSecurity:
            markAgentProposalHandedOff(proposal)
            appendAudit(.handoffOpened, instruction.title, details: ["target": proposal.handoffTarget.rawValue])
            appState.requestWalletSection(.security)
        case .walletActivity:
            markAgentProposalHandedOff(proposal)
            appendAudit(.handoffOpened, instruction.title, details: ["target": proposal.handoffTarget.rawValue])
            appState.requestWalletSection(.activity)
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

    private func appendAudit(_ kind: AgentAuditEvent.Kind, _ message: String, details: [String: String] = [:]) {
        var events = auditTimeline.events
        events.insert(AgentAuditEvent(kind: kind, message: message, details: details), at: 0)
        auditTimeline = AgentAuditTimeline(events: Array(events.prefix(50)))
    }

    private func clearAgentMemory() {
        agentMemory.clear()
        appendAudit(.memoryCleared, "Agent memory cleared.")
    }

    private func toolExecutionContext() -> AgentToolExecutionContext {
        AgentToolExecutionContext(
            portfolioSummary: walletManager.portfolioSummary,
            pnlSummary: walletManager.portfolioPnLSummary,
            pusdCirculationSnapshot: walletManager.pusdCirculationSnapshot,
            auditEvents: walletManager.auditEvents,
            selectedProfile: walletManager.selectedProfile,
            selectedNetwork: walletManager.selectedNetwork,
            walletBalance: walletManager.balance,
            vaultState: walletManager.vaultState,
            rpcSecurityStatus: walletManager.rpcProviderSecurityStatus,
        )
    }

    private func readOnlyFallbackResult(for classification: AgentIntentClassification) -> AgentToolResult {
        switch classification.intentType {
        case .help, .whatCanYouDo:
            return AgentToolResult(
                title: "Full-app Agent help",
                status: .readyForReview,
                summary: "I can summarize, draft, and hand off across Wallet, Portfolio, Activity, Security, and RPC. I cannot execute directly from chat.",
                bullets: [
                    "Ask for Wallet overview, security status, RPC status, activity, assets, PUSD, liquidity, yield, or PnL.",
                    "Ask to prepare swaps, sends, or PUSD payments; they become proposals.",
                    "Every executable request must continue in the destination review flow."
                ]
            )
        default:
            return AgentDeFiOpportunityAnalyzer.analyze(
                classification: classification,
                portfolioSummary: walletManager.portfolioSummary,
                pnlSummary: walletManager.portfolioPnLSummary,
                auditEvents: walletManager.auditEvents
            )
        }
    }
}
