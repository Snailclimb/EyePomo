import EyePomoCore
import Foundation

enum SettingsLanguage: String, Codable, CaseIterable, Identifiable {
    case chinese
    case english

    var id: String { rawValue }
}

struct AppSettings: Codable, Equatable {
    var language: SettingsLanguage
    var customDataDirectoryPath: String?

    init(language: SettingsLanguage = .chinese, customDataDirectoryPath: String? = nil) {
        self.language = language
        self.customDataDirectoryPath = customDataDirectoryPath
    }

    var dataDirectoryURL: URL {
        guard let customDataDirectoryPath, !customDataDirectoryPath.isEmpty else {
            return AppPaths.defaultApplicationSupportDirectory
        }
        return URL(fileURLWithPath: customDataDirectoryPath, isDirectory: true)
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
