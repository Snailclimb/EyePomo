import AppKit
import SwiftUI

// MARK: - Dynamic color helper

extension Color {
    /// 适配浅色/深色的动态色。在 SwiftUI `preferredColorScheme` 与 AppKit
    /// `NSWindow/NSPopover.appearance` 的共同作用下，渲染时按当前外观选取对应值。
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [
                .darkAqua,
                .vibrantDark,
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastVibrantDark
            ]) != nil
            return NSColor(isDark ? dark : light)
        })
    }
}

// MARK: - Font scale

@MainActor
enum AppFont {
    /// 由 `AppCoordinator` 在设置变化与启动时同步。所有字号经 `font(_:)` 乘以此系数。
    static var scale: CGFloat = 1.0

    /// 按当前缩放系数生成字体。小于 11pt 的小字施加 9pt 下限，避免紧凑档下糊掉。
    static func font(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let scaled = size < 11 ? max(9, size * scale) : size * scale
        return .system(size: scaled, weight: weight, design: design)
    }
}

// MARK: - Accent palette

@MainActor
enum AppPalette {
    /// 由 `AppCoordinator` 同步；`EyePomoTheme.teal/tomato` 读取此值。
    static var current: AccentPalette = .eyeCare

    /// 主强调色（眼休/休息/完成/进度）。
    static func teal(for palette: AccentPalette) -> Color {
        switch palette {
        case .eyeCare:
            return Color(red: 45 / 255, green: 181 / 255, blue: 172 / 255)
        case .ocean:
            return Color(red: 48 / 255, green: 128 / 255, blue: 235 / 255)
        case .forest:
            return Color(red: 88 / 255, green: 174 / 255, blue: 92 / 255)
        case .violet:
            return Color(red: 149 / 255, green: 97 / 255, blue: 226 / 255)
        }
    }

    /// 专注/番茄强调色，保持暖色，与 `teal` 形成冷暖对比。
    static func tomato(for palette: AccentPalette) -> Color {
        switch palette {
        case .eyeCare:
            return Color(red: 224 / 255, green: 90 / 255, blue: 58 / 255)
        case .ocean:
            return Color(red: 255 / 255, green: 120 / 255, blue: 73 / 255)
        case .forest:
            return Color(red: 214 / 255, green: 69 / 255, blue: 65 / 255)
        case .violet:
            return Color(red: 235 / 255, green: 68 / 255, blue: 128 / 255)
        }
    }
}

// MARK: - Density

struct DensityMetrics {
    let cornerRadius: CGFloat
    let contentPadding: CGFloat
    let sectionSpacing: CGFloat
}

@MainActor
enum AppDensityProfile {
    /// 由 `AppCoordinator` 同步；影响卡片圆角、内边距、区块间距等关键视觉密度。
    static var current: AppDensity = .standard

    static var metrics: DensityMetrics {
        switch current {
        case .compact:
            return DensityMetrics(cornerRadius: 8, contentPadding: 20, sectionSpacing: 16)
        case .standard:
            return DensityMetrics(cornerRadius: 10, contentPadding: 24, sectionSpacing: 20)
        case .comfortable:
            return DensityMetrics(cornerRadius: 12, contentPadding: 28, sectionSpacing: 24)
        }
    }
}

// MARK: - Appearance mode helpers

@MainActor
enum Appearance {
    /// SwiftUI 层外观。`.system` 显式解析当前系统外观（而非返回 nil），
    /// 这样系统切换时配合 KVO 重设能真正触发 SwiftUI 重算。
    static func resolvedColorScheme(_ mode: AppearanceMode) -> ColorScheme? {
        switch mode {
        case .system: return systemIsDark() ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// 读取当前系统外观是否为深色。`.system` 模式据此显式解析为 light/dark，
    /// 避免依赖 `appearance = nil` 的隐式跟随（NSPopover / NSPanel 上不可靠）。
    static func systemIsDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [
            .darkAqua,
            .vibrantDark,
            .accessibilityHighContrastDarkAqua,
            .accessibilityHighContrastVibrantDark
        ]) != nil
    }

    static func nsAppearance(_ mode: AppearanceMode) -> NSAppearance? {
        switch mode {
        case .system: return systemIsDark() ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    /// 同步 NSWindow 的 appearance 与背景色，使标题栏等原生 chrome 与 SwiftUI 内容一致。
    static func apply(_ mode: AppearanceMode, toWindow window: NSWindow) {
        window.appearance = nsAppearance(mode)
        window.backgroundColor = backgroundColor(mode)
    }

    /// 同步 NSPopover 的 appearance，使箭头/边框与内容一致。
    static func apply(_ mode: AppearanceMode, toPopover popover: NSPopover) {
        popover.appearance = nsAppearance(mode)
    }

    static func backgroundColor(_ mode: AppearanceMode) -> NSColor {
        switch mode {
        case .system:
            return .windowBackgroundColor
        case .light:
            return NSColor(srgbRed: 246 / 255, green: 246 / 255, blue: 248 / 255, alpha: 1)
        case .dark:
            return NSColor(srgbRed: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
        }
    }
}

// MARK: - Theme colors

@MainActor
enum EyePomoTheme {
    /// 强调色随 `AppPalette.current` 变化；引用处无需改动。
    static var teal: Color { AppPalette.teal(for: AppPalette.current) }
    static var tomato: Color { AppPalette.tomato(for: AppPalette.current) }

    static let panelBackground = Color.dynamic(
        light: Color(red: 250 / 255, green: 250 / 255, blue: 252 / 255),
        dark: Color(red: 20 / 255, green: 23 / 255, blue: 26 / 255)
    )
    static let settingsBackground = Color.dynamic(
        light: Color(red: 244 / 255, green: 244 / 255, blue: 247 / 255),
        dark: Color(red: 16 / 255, green: 18 / 255, blue: 21 / 255)
    )
    static let cardBackground = Color.dynamic(
        light: Color.white,
        dark: Color(red: 29 / 255, green: 33 / 255, blue: 37 / 255)
    )
    static let border = Color.dynamic(light: Color.black.opacity(0.10), dark: Color.white.opacity(0.08))
    static let primaryText = Color.dynamic(light: Color.black.opacity(0.86), dark: Color.white.opacity(0.94))
    static let secondaryText = Color.dynamic(light: Color.black.opacity(0.55), dark: Color.white.opacity(0.62))
}

// MARK: - Button styles

struct PrimaryPanelButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.font(13, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.86))
            .padding(.vertical, 9)
            .background(accent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct SecondaryPanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.font(12, weight: .medium))
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
