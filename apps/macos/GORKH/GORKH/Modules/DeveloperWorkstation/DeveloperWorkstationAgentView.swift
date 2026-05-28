import SwiftUI

struct DeveloperWorkstationAgentView: View {
    let activeProject: WorkstationProject?
    let selectedCluster: WorkstationCluster
    let currentProjectBrain: DeveloperProjectBrain?
    let parsedIDL: WorkstationIDL?
    let transactionDebugReport: TransactionDebugReport?
    @Binding var mode: DeveloperAgentMode
    @Binding var toolID: String
    @Binding var prompt: String
    @Binding var instructionName: String
    @Binding var signature: String
    @Binding var programID: String
    @Binding var seed: String
    @Binding var accountAddress: String
    @Binding var accountDataBase64: String
    @Binding var idlAccountName: String
    @Binding var rpcMethod: WorkstationRPCMethod
    @Binding var operation: WorkstationProgramOperation
    @Binding var draftKind: FrontendGeneratedFileKind
    @Binding var approvalPhrase: String
    let message: String
    let history: [DeveloperAgentToolCallRecord]
    let isCallingTool: Bool
    let dateFormatter: DateFormatter
    let onRunTool: () -> Void
    let onRecordBoundaryReview: () -> Void

    // Chat / Proposal-first additions
    var chatMessages: [AgentChatMessage] = []
    @Binding var chatInput: String
    var activeProposal: AgentProposalCardDisplay?
    let onSubmitChat: () -> Void
    let onApproveProposal: () -> Void
    let onRejectProposal: () -> Void

    var body: some View {
        let selectedTool = DeveloperAgentToolRegistry.tool(id: toolID) ?? DeveloperAgentToolRegistry.allowedTools.first
        let authorization = DeveloperAgentToolRegistry.authorize(
            toolID: toolID,
            mode: mode,
            project: activeProject,
            cluster: selectedCluster
        )

        return VStack(alignment: .leading, spacing: 14) {
            headerPanel
            chatPanel
            if let proposal = activeProposal {
                AgentSystemProposalCardView(
                    display: proposal,
                    onPrimaryAction: onApproveProposal,
                    onReject: onRejectProposal
                )
            }
            toolAndTimeline(selectedTool: selectedTool, authorization: authorization)
            registryPanel
        }
    }

    private var chatPanel: some View {
        GorkhPanel("Chat / Intent") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Write what you need. Developer Workstation Agent will create a tool proposal.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.primaryText)
                Text("Read-only tools can run through workstation gates.")
                    .font(.caption2)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text("Build/test/deploy actions require project trust, fixed preview, and approval.")
                    .font(.caption2)
                    .foregroundStyle(GorkhColors.secondaryText)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chatMessages) { message in
                            HStack {
                                if message.role == .user { Spacer() }
                                Text(message.text)
                                    .font(.caption)
                                    .padding(8)
                                    .background(message.role == .user ? GorkhColors.panelElevated : GorkhColors.panel)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .foregroundStyle(message.role == .user ? GorkhColors.primaryText : GorkhColors.secondaryText)
                                if message.role != .user { Spacer() }
                            }
                        }
                    }
                }
                .frame(minHeight: 60, maxHeight: 160)

                HStack(spacing: 10) {
                    TextField("Ask Workstation Agent to scan, debug, decode, test, or review…", text: $chatInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { onSubmitChat() }
                    Button(action: onSubmitChat) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var headerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            AgentBoundaryBanner(manifest: .developerWorkstation, compact: true)

            GorkhPanel("Developer Workstation Agent") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Developer Workstation Agent is scoped to Solana developer tooling.")
                        .font(.headline)
                        .foregroundStyle(GorkhColors.primaryText)
                    Text("It is not autonomous. It cannot use the main KeySlot wallet.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("Build/test/deploy actions require project trust, fixed command preview, and approval.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text("Mainnet program deploy/upgrade/close/authority mutation remains locked.")
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().overlay(GorkhColors.border)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], alignment: .leading, spacing: 10) {
                    DeveloperWorkstationMetricCard(title: "Project", value: activeProject?.displayName ?? "None", detail: activeProject?.trustStatus.title ?? "Import a project")
                    DeveloperWorkstationMetricCard(title: "Cluster", value: selectedCluster.title, detail: selectedCluster.programOpsMode.title)
                    DeveloperWorkstationMetricCard(title: "Project Brain", value: currentProjectBrain == nil ? "Missing" : "Loaded", detail: currentProjectBrain.map { "\($0.instructions.count) instructions" } ?? "Scan first")
                    DeveloperWorkstationMetricCard(title: "IDL", value: parsedIDL?.name ?? "Missing", detail: parsedIDL?.summary ?? "Load an IDL")
                    DeveloperWorkstationMetricCard(title: "Tx Debug", value: transactionDebugReport?.status.title ?? "Missing", detail: transactionDebugReport?.signature ?? "Fetch a transaction")
                }
            }
        }
    }

    private func toolAndTimeline(
        selectedTool: WorkstationAgentTool?,
        authorization: DeveloperAgentAuthorization
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            toolCallPanel(selectedTool: selectedTool, authorization: authorization)
            timelinePanel
        }
    }

    private func toolCallPanel(
        selectedTool: WorkstationAgentTool?,
        authorization: DeveloperAgentAuthorization
    ) -> some View {
        GorkhPanel("Tool Call") {
            Picker("Mode", selection: $mode) {
                ForEach(DeveloperAgentMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Picker("Tool", selection: $toolID) {
                ForEach(DeveloperAgentToolRegistry.allowedTools) { tool in
                    Text(tool.displayName).tag(tool.id)
                }
            }

            if let selectedTool {
                agentToolRow(selectedTool)
                HStack {
                    statusChip(
                        authorization.allowed ? "Allowed by current context" : "Blocked by current context",
                        color: authorization.allowed ? GorkhColors.success : GorkhColors.warning
                    )
                    if authorization.approvalRequired {
                        statusChip("Approval required", color: GorkhColors.warning)
                    }
                }
                if !authorization.reasons.isEmpty {
                    ForEach(authorization.reasons, id: \.self) { reason in
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(GorkhColors.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            promptEditor
            toolInputs

            if authorization.approvalRequired {
                approvalCard
            }

            HStack {
                Button {
                    onRunTool()
                } label: {
                    Label(isCallingTool ? "Running..." : "Run Tool Call", systemImage: "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCallingTool)

                Button("Record Boundary Review", action: onRecordBoundaryReview)
                    .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prompt / logs")
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            TextEditor(text: $prompt)
                .font(.caption.monospaced())
                .frame(minHeight: 84)
                .scrollContentBackground(.hidden)
                .background(GorkhColors.panelElevated)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(GorkhColors.border))
        }
    }

    private var toolInputs: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
                DeveloperWorkstationLabeledTextField(label: "Signature", text: $signature, prompt: "public tx signature")
                DeveloperWorkstationLabeledTextField(label: "Program ID", text: $programID, prompt: "program public key")
                DeveloperWorkstationLabeledTextField(label: "PDA seed", text: $seed, prompt: "state")
                DeveloperWorkstationLabeledTextField(label: "Account address", text: $accountAddress, prompt: "public account")
                DeveloperWorkstationLabeledTextField(label: "Account data base64", text: $accountDataBase64, prompt: "base64 fixture")
                DeveloperWorkstationLabeledTextField(label: "IDL account name", text: $idlAccountName, prompt: "Account type")
                DeveloperWorkstationLabeledTextField(label: "Instruction", text: $instructionName, prompt: "deposit")
            }

            HStack(spacing: 12) {
                Picker("RPC", selection: $rpcMethod) {
                    ForEach(WorkstationRPCMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                Picker("Operation", selection: $operation) {
                    ForEach(WorkstationProgramOperation.allCases) { operation in
                        Text(operation.title).tag(operation)
                    }
                }
                Picker("Draft", selection: $draftKind) {
                    ForEach(FrontendGeneratedFileKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            }
        }
    }

    private var approvalCard: some View {
        GorkhPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Approval Card")
                    .font(.headline)
                Text("This approval only lets Developer Agent hand off to the existing safe flow. It does not bypass command preview, trust, cluster, or Program Manager gates.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                DeveloperWorkstationLabeledTextField(label: "Approval phrase", text: $approvalPhrase, prompt: DeveloperWorkstationAgentService.approvalPhrase)
            }
        }
    }

    private var timelinePanel: some View {
        GorkhPanel("Tool Timeline") {
            if history.isEmpty {
                Text("No Developer Agent tool calls recorded yet.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                ForEach(history.prefix(10)) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            WorkstationStatusChip(
                                title: record.status.title,
                                systemImage: record.status == .blocked ? "lock.shield" : "checkmark.circle",
                                color: statusColor(record.status)
                            )
                            Text(record.toolName)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(dateFormatter.string(from: record.createdAt))
                                .font(.caption2)
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                        DeveloperWorkstationKeyValueRow(key: "Mode", value: record.mode.title)
                        DeveloperWorkstationKeyValueRow(key: "Input", value: record.inputSummary)
                        DeveloperWorkstationKeyValueRow(key: "Output", value: record.outputSummary)
                        if let blockReason = record.blockReason {
                            Text(blockReason)
                                .font(.caption)
                                .foregroundStyle(GorkhColors.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider().overlay(GorkhColors.border)
                }
            }
        }
    }

    private var registryPanel: some View {
        GorkhPanel("Tool Registry") {
            DisclosureGroup("Allowed typed tools") {
                ForEach(DeveloperAgentToolRegistry.allowedTools) { tool in
                    agentToolRow(tool)
                }
            }
            DisclosureGroup("Always blocked tools") {
                ForEach(DeveloperAgentToolRegistry.blockedTools) { tool in
                    agentToolRow(tool)
                }
            }
            Text("Write, execute, and chain-write tools remain behind existing Workstation trust, approval, localnet/devnet, evidence, and fixed-command gates.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func agentToolRow(_ tool: WorkstationAgentTool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                WorkstationStatusChip(
                    title: tool.modeRequired.title,
                    systemImage: tool.readOnly ? "eye" : "lock.shield",
                    color: tool.readOnly ? GorkhColors.success : GorkhColors.warning
                )
                Text(tool.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GorkhColors.primaryText)
                Spacer()
                Text(tool.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            Text(tool.reason)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Trusted project: \(tool.requiresTrustedProject ? "Required" : "No") | Approval: \(tool.approvalRequired ? "Required" : "No") | Clusters: \(tool.allowedClusters.map(\.title).joined(separator: ", ").ifEmpty("Any read-only context"))")
                .font(.caption2)
                .foregroundStyle(GorkhColors.secondaryText)
        }
        .padding(.vertical, 5)
    }

    private func statusColor(_ status: DeveloperAgentToolCallStatus) -> Color {
        switch status {
        case .succeeded, .delegated:
            return GorkhColors.success
        case .approvalRequired, .unavailable, .blocked:
            return GorkhColors.warning
        }
    }

    private func statusChip(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
