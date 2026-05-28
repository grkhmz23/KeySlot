import SwiftUI

/// Reusable chat scaffold for proposal-first agent surfaces.
/// Displays messages, active proposal cards, input, and safety copy.
struct AgentChatScaffoldView: View {
    let agentID: KeySlotAgentID
    let title: String
    let placeholder: String
    let safetyCopy: String
    let messages: [AgentChatMessage]
    @Binding var draftText: String
    let isThinking: Bool
    let proposalDisplays: [AgentProposalCardDisplay]
    let onSubmit: () -> Void
    let onPrimaryAction: (AgentProposalCardDisplay) -> Void
    let onReject: (AgentProposalCardDisplay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(safetyCopy)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)

            messageList

            if proposalDisplays.isEmpty == false {
                proposalCards
            }

            inputArea
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { message in
                        chatBubble(message)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 120, maxHeight: 280)
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func chatBubble(_ message: AgentChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? GorkhColors.primaryText : GorkhColors.secondaryText)
            }
            .padding(10)
            .background(message.role == .user ? GorkhColors.panelElevated : GorkhColors.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            if message.role != .user {
                Spacer()
            }
        }
        .id(message.id)
    }

    private var proposalCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(proposalDisplays) { display in
                AgentSystemProposalCardView(
                    display: display,
                    onPrimaryAction: { onPrimaryAction(display) },
                    onReject: { onReject(display) }
                )
            }
        }
    }

    private var inputArea: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $draftText)
                .textFieldStyle(.roundedBorder)
                .disabled(isThinking)
                .onSubmit {
                    onSubmit()
                }

            Button(action: onSubmit) {
                if isThinking {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .disabled(isThinking || draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

// MARK: - Convenience for Global Agent

/// Global Agent-specific chat scaffold.
struct GlobalAgentChatScaffoldView: View {
    @Binding var messages: [AgentChatMessage]
    @Binding var draftText: String
    let isThinking: Bool
    let proposalDisplays: [AgentProposalCardDisplay]
    let onSubmit: () -> Void
    let onPrimaryAction: (AgentProposalCardDisplay) -> Void
    let onReject: (AgentProposalCardDisplay) -> Void

    var body: some View {
        AgentChatScaffoldView(
            agentID: .global,
            title: "Global Agent Chat",
            placeholder: "Ask KeySlot to explain, review, draft, or route a task…",
            safetyCopy: "Write what you want. Global Agent will create a proposal. You approve, sign, or reject proposals. Sensitive actions use existing app approval flows. Global Agent cannot reveal private keys or seed phrases. Developer tooling belongs in Developer Workstation.",
            messages: messages,
            draftText: $draftText,
            isThinking: isThinking,
            proposalDisplays: proposalDisplays,
            onSubmit: onSubmit,
            onPrimaryAction: onPrimaryAction,
            onReject: onReject
        )
    }
}
