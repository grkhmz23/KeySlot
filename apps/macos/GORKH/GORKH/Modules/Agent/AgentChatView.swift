import SwiftUI

struct AgentChatView: View {
    let safetyPolicy: AgentSafetyPolicy
    @Binding var messages: [AgentChatMessage]
    @Binding var draftText: String
    let lastIntent: AgentIntentClassification?
    let proposals: [AgentProposal]
    let toolResults: [AgentToolResult]
    let memoryEntries: [AgentMemoryEntry]
    let aiStatus: AgentAIStatus
    let isAIResponding: Bool
    let submitAction: () -> Void
    let handoffAction: (AgentProposal) -> Void
    let clearMemoryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AgentGuardrailBannerView()
            GorkhPanel("Agent Chat") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        GorkhStatusChip(title: safetyPolicy.mainWalletAccess.label, systemImage: "xmark.shield", color: GorkhColors.warning)
                        GorkhStatusChip(title: "Proposals only", systemImage: "doc.badge.gearshape", color: GorkhColors.accent)
                        GorkhStatusChip(title: "Destination approval", systemImage: "checkmark.shield", color: GorkhColors.warning)
                        GorkhStatusChip(title: aiStatus.mode.title, systemImage: aiStatus.mode == .hostedDeepSeek ? "cloud" : "lock.shield", color: aiStatus.mode == .hostedDeepSeek ? GorkhColors.accent : GorkhColors.warning)
                    }
                }
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    AgentMessageTimelineView(messages: messages)

                    GorkhPanel {
                        HStack(spacing: 10) {
                            TextField("Ask about portfolio, swaps, PUSD, yield, LPs, or recent activity", text: $draftText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...3)
                                .accessibilityIdentifier("agent.chat.input")
                                .onSubmit(submitAction)

                            Button(action: submitAction) {
                                Label("Send", systemImage: "paperplane")
                            }
                            .buttonStyle(.keyslotPrimary)
                            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("agent.chat.send")
                        }
                    }
                }
                .frame(minWidth: 420)

                VStack(alignment: .leading, spacing: 12) {
                    AgentAIStatusView(status: aiStatus, isResponding: isAIResponding)
                    AgentFullAppHelpView()

                    if let lastIntent {
                        AgentIntentCardView(classification: lastIntent)
                    }

                    if toolResults.isEmpty == false {
                        ForEach(toolResults.prefix(3)) { result in
                            AgentToolResultCardView(result: result)
                        }
                    }

                    if proposals.isEmpty {
                        GorkhPanel("Proposals") {
                            Text("Executable requests become proposal cards here. Read-only questions produce analysis cards only.")
                                .foregroundStyle(GorkhColors.secondaryText)
                        }
                    } else {
                        ForEach(proposals.prefix(5)) { proposal in
                            AgentProposalCardView(proposal: proposal, handoffAction: handoffAction)
                        }
                    }

                    AgentApprovalQueueView(proposals: proposals)

                    if memoryEntries.isEmpty == false {
                        GorkhPanel("Recent Agent Context") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(memoryEntries.prefix(4)) { entry in
                                    Text("\(entry.intentType.title): \(entry.summary)")
                                        .font(.caption)
                                        .foregroundStyle(GorkhColors.secondaryText)
                                        .lineLimit(2)
                                }

                                Button {
                                    clearMemoryAction()
                                } label: {
                                    Label("Clear memory", systemImage: "trash")
                                }
                                .buttonStyle(.keyslotSecondary)
                                .accessibilityIdentifier("agent.memory.clear")
                            }
                        }
                    }
                }
                .frame(minWidth: 360)
            }
        }
        .accessibilityIdentifier("agent.chat")
    }
}
