import CoreGraphics
import EyePomoCore
import Foundation

enum SettingsLanguage: String, Codable, CaseIterable, Identifiable {
    case chinese
    case english

    var id: String { rawValue }
}

/// 外观模式：跟随系统 / 强制浅色 / 强制深色。
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

/// UI 字号档位。实际字号 = 基础字号 × multiplier。
enum FontScale: String, Codable, CaseIterable, Identifiable {
    case compact
    case standard
    case comfortable

    var id: String { rawValue }

    var multiplier: CGFloat {
        switch self {
        case .compact: return 0.9
        case .standard: return 1.0
        case .comfortable: return 1.12
        }
    }
}

/// 强调色预设。每套提供 teal（眼休/休息/进度）与 tomato（专注/番茄），
/// 两者保持冷暖对比以便区分状态。
enum AccentPalette: String, Codable, CaseIterable, Identifiable {
    case eyeCare
    case ocean
    case forest
    case violet

    var id: String { rawValue }
}

/// 界面密度档位，影响卡片圆角、内边距、区块间距等关键视觉密度。
enum AppDensity: String, Codable, CaseIterable, Identifiable {
    case compact
    case standard
    case comfortable

    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable, Hashable {
    var language: SettingsLanguage
    var customDataDirectoryPath: String?
    var appearance: AppearanceMode
    var fontScale: FontScale
    var accentPalette: AccentPalette
    var density: AppDensity

    init(
        language: SettingsLanguage = .chinese,
        customDataDirectoryPath: String? = nil,
        appearance: AppearanceMode = .system,
        fontScale: FontScale = .standard,
        accentPalette: AccentPalette = .eyeCare,
        density: AppDensity = .standard
    ) {
        self.language = language
        self.customDataDirectoryPath = customDataDirectoryPath
        self.appearance = appearance
        self.fontScale = fontScale
        self.accentPalette = accentPalette
        self.density = density
    }

    var dataDirectoryURL: URL {
        guard let customDataDirectoryPath, !customDataDirectoryPath.isEmpty else {
            return AppPaths.defaultApplicationSupportDirectory
        }
        return URL(fileURLWithPath: customDataDirectoryPath, isDirectory: true)
    }

    // MARK: Codable
    // 容错解码：旧版 JSON 缺失新字段时回退到默认值，保留 language 与 customDataDirectoryPath，
    // 避免 bump key 与数据丢失。

    private enum CodingKeys: String, CodingKey {
        case language
        case customDataDirectoryPath
        case appearance
        case fontScale
        case accentPalette
        case density
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 用 `try? decode` 同时容错「字段缺失」与「非法 enum rawValue」，
        // 避免单个坏值导致整个 AppSettings 回默认而丢失 language / 数据目录。
        language = (try? container.decode(SettingsLanguage.self, forKey: .language)) ?? .chinese
        customDataDirectoryPath = try? container.decodeIfPresent(String.self, forKey: .customDataDirectoryPath)
        appearance = (try? container.decode(AppearanceMode.self, forKey: .appearance)) ?? .system
        fontScale = (try? container.decode(FontScale.self, forKey: .fontScale)) ?? .standard
        accentPalette = (try? container.decode(AccentPalette.self, forKey: .accentPalette)) ?? .eyeCare
        density = (try? container.decode(AppDensity.self, forKey: .density)) ?? .standard
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(language, forKey: .language)
        try container.encodeIfPresent(customDataDirectoryPath, forKey: .customDataDirectoryPath)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(fontScale, forKey: .fontScale)
        try container.encode(accentPalette, forKey: .accentPalette)
        try container.encode(density, forKey: .density)
    }
}

struct SettingsStore {
    private let key = "EyePomo.preferences.v1"
    private let defaults = UserDefaults.standard

    func load() -> AppPreferences? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(AppPreferences.self, from: data)
    }

    func save(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct AppSettingsStore {
    private let key = "EyePomo.appSettings.v1"
    private let defaults = UserDefaults.standard

    func load() -> AppSettings? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
