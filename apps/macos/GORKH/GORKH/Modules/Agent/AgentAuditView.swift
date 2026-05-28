import SwiftUI

struct AgentAuditView: View {
    let timeline: AgentAuditTimeline

    var body: some View {
        GorkhPanel("Agent Audit") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Safe local timeline for Agent readiness events. Secrets, tokens, and raw command payloads are redacted.")
                    .foregroundStyle(GorkhColors.secondaryText)

                if timeline.events.isEmpty {
                    Text("No Agent events yet.")
                        .foregroundStyle(GorkhColors.secondaryText)
                } else {
                    ForEach(timeline.events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.kind.label)
                                    .font(.headline)
                                    .foregroundStyle(GorkhColors.primaryText)
                                Spacer()
                                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(GorkhColors.secondaryText)
                            }
                            Text(event.message)
                                .foregroundStyle(GorkhColors.secondaryText)
                            if event.details.isEmpty == false {
                                DisclosureGroup("Technical details") {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(event.details.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                            Text("\(key): \(value)")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(GorkhColors.secondaryText)
                                        }
                                    }
                                }
                            }
                        }
                        Divider().overlay(GorkhColors.border)
                    }
                }
            }
        }
        .accessibilityIdentifier("agent.audit")
    }
}
