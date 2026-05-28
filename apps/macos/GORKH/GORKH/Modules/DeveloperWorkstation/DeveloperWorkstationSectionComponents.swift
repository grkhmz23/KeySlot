import SwiftUI

struct DeveloperWorkstationMetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        GorkhPanel {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(GorkhColors.primaryText)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                    .lineLimit(2)
            }
        }
    }
}

struct DeveloperWorkstationKeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
                .frame(width: 118, alignment: .leading)
            if shouldScrollValue(value) {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(value)
                        .font(.caption.monospaced())
                        .foregroundStyle(GorkhColors.primaryText)
                        .textSelection(.enabled)
                        .padding(.bottom, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.primaryText)
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
    }

    private func shouldScrollValue(_ value: String) -> Bool {
        value.count > 72 || value.contains("/") || value.contains("--") || value.contains("://")
    }
}

struct DeveloperWorkstationScrollingMonospacedText: View {
    let value: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(GorkhColors.secondaryText)
                .textSelection(.enabled)
                .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DeveloperWorkstationLabeledTextField: View {
    let label: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(GorkhColors.secondaryText)
            TextField(prompt, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
