import SwiftUI

struct AgentView: View {
    @State private var selectedSection: AgentSection = .overview
    @State private var statusSnapshot = ZerionStatusService().localSnapshot()
    @State private var policySnapshot = ZerionPolicyCenterSnapshot.unchecked
    @State private var auditTimeline = AgentAuditTimeline.initial
    @State private var proposals: [ZerionProposal] = [.sampleDraft]
    @State private var tinySwapProposals: [ZerionTinySwapProposal] = []
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
                        snapshot: AgentOverviewSnapshot.from(status: statusSnapshot, draftProposalCount: proposals.count + tinySwapProposals.count),
                        safetyPolicy: safetyPolicy,
                        refreshAction: refreshStatus
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
                Text("Observe wallet context, inspect Zerion readiness, and review one policy-scoped tiny swap.")
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Spacer()

            GorkhStatusChip(title: "A2 tiny swap gated", systemImage: "lock.shield", color: GorkhColors.warning)
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
                    GorkhStatusChip(title: "Tiny swap only", systemImage: "arrow.left.arrow.right", color: GorkhColors.warning)
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
