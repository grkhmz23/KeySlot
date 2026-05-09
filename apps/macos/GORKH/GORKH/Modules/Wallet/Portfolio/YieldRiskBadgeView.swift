import SwiftUI

struct YieldRiskBadgeView: View {
    let level: YieldRiskLevel

    var body: some View {
        GorkhStatusChip(title: level.title, systemImage: "gauge.with.dots.needle.33percent", color: color)
    }

    private var color: Color {
        switch level {
        case .low:
            return GorkhColors.success
        case .medium:
            return GorkhColors.warning
        case .high:
            return GorkhColors.danger
        case .unavailable:
            return GorkhColors.secondaryText
        }
    }
}
