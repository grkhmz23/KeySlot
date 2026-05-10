import SwiftUI

struct AgentView: View {
    @State private var selectedSection: AgentSection = .overview
    @State private var statusSnapshot = ZerionStatusService().localSnapshot()
    @State private var policySnapshot = ZerionPolicyCenterSnapshot.unchecked
    @State private var auditTimeline = AgentAuditTimeline.initial
    @State private var proposals: [ZerionProposal] = [.sampleDraft]
    @State private var isRefreshing = false

    private let safetyPolicy = AgentSafetyPolicy.zerionA1
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
                        snapshot: AgentOverviewSnapshot.from(status: statusSnapshot, draftProposalCount: proposals.count),
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
                    ZerionProposalView(proposals: proposals)
                case .audit:
                    AgentAuditView(timeline: auditTimeline)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("agent.root")
        .onAppear {
            appendAudit(.agentSectionViewed, "Agent section opened in A1 no-execution mode.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("Observe wallet context, inspect Zerion readiness, and draft future policy-scoped actions.")
                    .foregroundStyle(GorkhColors.secondaryText)
            }

            Spacer()

            GorkhStatusChip(title: "A1 no execution", systemImage: "lock.shield", color: GorkhColors.warning)
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
                    GorkhStatusChip(title: "No Zerion trading", systemImage: "lock", color: GorkhColors.warning)
                    GorkhStatusChip(title: "Draft proposals only", systemImage: "doc.text", color: GorkhColors.accent)
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
        policySnapshot = ZerionPolicyCenterSnapshot(
            policies: [],
            tokens: snapshot.agentTokenStatus == .presentRedacted ? [.unknown] : [],
            status: snapshot.policyStatus,
            unavailableReason: snapshot.errors.first,
            updatedAt: snapshot.checkedAt
        )
        appendAudit(.zerionCLIStatusChecked, "Zerion read/status refresh completed.")
        appendAudit(.zerionAPIKeyStatusChecked, "Zerion API key status: \(snapshot.apiKeyStatus.label).")
        if snapshot.policyStatus == .loaded {
            appendAudit(.zerionPoliciesChecked, "Zerion policies/tokens checked.")
        }
        isRefreshing = false
    }

    private func appendAudit(_ kind: AgentAuditEvent.Kind, _ message: String) {
        var events = auditTimeline.events
        events.insert(AgentAuditEvent(kind: kind, message: message), at: 0)
        auditTimeline = AgentAuditTimeline(events: Array(events.prefix(50)))
    }
}
