import SwiftUI

struct DeveloperWorkstationLogsView: View {
    @Binding var programID: String
    let logState: WorkstationLogStreamState
    let onToggleLogs: () -> Void

    var body: some View {
        GorkhPanel("Program Logs") {
            DeveloperWorkstationLabeledTextField(label: "Program id", text: $programID, prompt: "Program public key")
            HStack {
                Button(logState.isStreaming ? "Stop Stream" : "Start Stream", action: onToggleLogs)
                    .buttonStyle(.borderedProminent)
                WorkstationStatusChip(
                    title: logState.isStreaming ? "Streaming" : "Stopped",
                    systemImage: logState.isStreaming ? "dot.radiowaves.left.and.right" : "pause.circle",
                    color: logState.isStreaming ? GorkhColors.success : GorkhColors.secondaryText
                )
                Spacer()
                Text("Buffer: \(logState.entries.count)/\(logState.maxEntries)")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            }
            if logState.entries.isEmpty {
                Text("No logs captured. Log streaming is read-only and bounded.")
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
            } else {
                ForEach(logState.entries.suffix(20)) { entry in
                    DeveloperWorkstationScrollingMonospacedText(value: entry.line)
                }
            }
        }
    }
}

struct DeveloperWorkstationOfflineSigningView: View {
    var body: some View {
        GorkhPanel("Offline Signing Foundation") {
            let state = WorkstationOfflineSigningState.foundation
            DeveloperWorkstationKeyValueRow(key: "Status", value: state.status.rawValue)
            Text(state.message)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            WorkstationStatusChip(title: "No signing or broadcast in D1", systemImage: "lock.shield", color: GorkhColors.warning)
        }
    }
}

struct DeveloperWorkstationActivityView: View {
    let activity: [WorkstationActivityEvent]

    var body: some View {
        GorkhPanel("Workstation Activity") {
            Text("Redaction is heuristic. Unknown secret formats may still be risky, and tool history is a redacted summary, not full forensic replay.")
                .font(.caption)
                .foregroundStyle(GorkhColors.warning)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(activity.prefix(80)) { event in
                HStack(alignment: .top) {
                    Text(event.kind.title)
                        .frame(width: 160, alignment: .leading)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.secondaryText)
                    Text(event.message)
                        .font(.caption)
                        .foregroundStyle(GorkhColors.primaryText)
                    Spacer()
                }
            }
        }
    }
}
