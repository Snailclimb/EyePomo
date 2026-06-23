import SwiftUI

enum EyePomoTheme {
    static let teal = Color(red: 45 / 255, green: 181 / 255, blue: 172 / 255)
    static let tomato = Color(red: 224 / 255, green: 90 / 255, blue: 58 / 255)
    static let panelBackground = Color(red: 20 / 255, green: 23 / 255, blue: 26 / 255)
    static let settingsBackground = Color(red: 16 / 255, green: 18 / 255, blue: 21 / 255)
    static let cardBackground = Color(red: 29 / 255, green: 33 / 255, blue: 37 / 255)
    static let border = Color.white.opacity(0.08)
    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
}

struct PrimaryPanelButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.86))
            .padding(.vertical, 9)
            .background(accent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct SecondaryPanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(EyePomoTheme.primaryText)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(EyePomoTheme.cardBackground.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(EyePomoTheme.border, lineWidth: 1)
            )
    }
}
