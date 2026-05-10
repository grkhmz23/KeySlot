import SwiftUI

struct AgentMessageTimelineView: View {
    let messages: [AgentChatMessage]

    var body: some View {
        GorkhPanel("Conversation") {
            VStack(alignment: .leading, spacing: 10) {
                if messages.isEmpty {
                    Text("Ask for a portfolio summary, yield review, LP review, PUSD payment draft, private payment draft, or policy-scoped Zerion tiny swap.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                GorkhStatusChip(
                                    title: message.role.title,
                                    systemImage: message.role.systemImage,
                                    color: message.role == .user ? GorkhColors.accent : GorkhColors.warning
                                )
                                Spacer()
                                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            Text(message.text)
                                .foregroundStyle(GorkhColors.primaryText)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(message.role == .user ? GorkhColors.accent.opacity(0.08) : GorkhColors.border.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: 420, alignment: .top)
        }
    }
}

private extension AgentMessageRole {
    var title: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "Agent"
        case .system:
            return "System"
        }
    }

    var systemImage: String {
        switch self {
        case .user:
            return "person"
        case .assistant:
            return "sparkles"
        case .system:
            return "gearshape"
        }
    }
}
