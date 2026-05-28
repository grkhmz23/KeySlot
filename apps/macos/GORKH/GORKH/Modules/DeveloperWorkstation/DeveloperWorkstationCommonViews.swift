import SwiftUI

extension DeveloperWorkstationView {
    func overviewCard(_ title: String, value: String, detail: String) -> some View {
        DeveloperWorkstationMetricCard(title: title, value: value, detail: detail)
    }

    func compatibilityVersionCard(_ title: String, _ value: String?) -> some View {
        GorkhPanel {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(GorkhColors.secondaryText)
                Text(value ?? "Unavailable")
                    .font(.caption.monospaced())
                    .foregroundStyle(value == nil ? GorkhColors.warning : GorkhColors.primaryText)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
    }

    func labeledTextField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        DeveloperWorkstationLabeledTextField(label: label, text: text, prompt: prompt)
    }

    func keyValue(_ key: String, _ value: String) -> some View {
        DeveloperWorkstationKeyValueRow(key: key, value: value)
    }

    func scrollingMonospacedText(_ value: String) -> some View {
        DeveloperWorkstationScrollingMonospacedText(value: value)
    }

}
