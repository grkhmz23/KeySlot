import SwiftUI

struct GorkhStatusChip: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}
