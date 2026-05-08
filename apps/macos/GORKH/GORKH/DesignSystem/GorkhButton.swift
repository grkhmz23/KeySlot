import SwiftUI

struct GorkhButtonStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
        case danger
    }

    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var background: Color {
        switch tone {
        case .primary:
            return GorkhColors.accent
        case .secondary:
            return GorkhColors.panelElevated
        case .danger:
            return GorkhColors.danger
        }
    }

    private var foreground: Color {
        switch tone {
        case .primary, .danger:
            return .white
        case .secondary:
            return GorkhColors.primaryText
        }
    }
}

extension ButtonStyle where Self == GorkhButtonStyle {
    static var gorkhPrimary: GorkhButtonStyle { GorkhButtonStyle(tone: .primary) }
    static var gorkhSecondary: GorkhButtonStyle { GorkhButtonStyle(tone: .secondary) }
    static var gorkhDanger: GorkhButtonStyle { GorkhButtonStyle(tone: .danger) }
}
