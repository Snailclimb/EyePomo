import EyePomoCore
import Foundation

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
