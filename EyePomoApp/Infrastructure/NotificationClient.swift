import EyePomoCore
import Foundation
import UserNotifications

struct NotificationSettingsSnapshot: Sendable, Equatable {
    var isAvailable: Bool
    var isAuthorized: Bool
    var alertsAllowed: Bool
    var soundsAllowed: Bool

    static let unknown = NotificationSettingsSnapshot(
        isAvailable: false,
        isAuthorized: false,
        alertsAllowed: false,
        soundsAllowed: false
    )

    static let unavailable = NotificationSettingsSnapshot(
        isAvailable: false,
        isAuthorized: false,
        alertsAllowed: false,
        soundsAllowed: false
    )

    var allowsAudibleAppCue: Bool {
        isAvailable && isAuthorized && alertsAllowed && soundsAllowed
    }

    init(
        isAvailable: Bool,
        isAuthorized: Bool,
        alertsAllowed: Bool,
        soundsAllowed: Bool
    ) {
        self.isAvailable = isAvailable
        self.isAuthorized = isAuthorized
        self.alertsAllowed = alertsAllowed
        self.soundsAllowed = soundsAllowed
    }

    init(settings: UNNotificationSettings, isAvailable: Bool) {
        self.init(
            isAvailable: isAvailable,
            isAuthorized: Self.isAuthorized(settings.authorizationStatus),
            alertsAllowed: settings.alertSetting == .enabled,
            soundsAllowed: settings.soundSetting == .enabled
        )
    }

    private static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional:
            return true
        case .denied, .notDetermined:
            return false
        case .ephemeral:
            return true
        @unknown default:
            return false
        }
    }
}

struct NotificationSoundCue: Sendable, Equatable {
    var soundName: String
    var title: String
    var body: String
}

final class NotificationClient {
    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    func requestAuthorizationIfNeeded(
        completion: @MainActor @escaping (NotificationSettingsSnapshot) -> Void = { _ in }
    ) {
        guard isAvailable else {
            Task { @MainActor in completion(.unavailable) }
            return
        }

        let isAvailable = isAvailable
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Self.loadSettings(isAvailable: isAvailable, completion: completion)
        }
    }

    func refreshSettings(
        completion: @MainActor @escaping (NotificationSettingsSnapshot) -> Void
    ) {
        guard isAvailable else {
            Task { @MainActor in completion(.unavailable) }
            return
        }

        Self.loadSettings(isAvailable: isAvailable, completion: completion)
    }

    private static func loadSettings(
        isAvailable: Bool,
        completion: @MainActor @escaping (NotificationSettingsSnapshot) -> Void
    ) {
        UNUserNotificationCenter.current().getNotificationSettings { [isAvailable] settings in
            let snapshot = NotificationSettingsSnapshot(settings: settings, isAvailable: isAvailable)
            Task { @MainActor in completion(snapshot) }
        }
    }

    func deliverOverlayNotification(_ request: OverlayRequest, soundName: String? = nil) {
        guard isAvailable else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title(for: request.kind)
        content.body = request.message
        content.sound = soundName.map(notificationSound(named:))

        let request = UNNotificationRequest(
            identifier: "eyepomo-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func deliverPreReminderNotification(_ request: PreReminderRequest) {
        guard isAvailable else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "眼休即将开始"
        content.body = request.message
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "eyepomo-prereminder-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func deliverSoundCue(_ cue: NotificationSoundCue) {
        guard isAvailable else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = cue.title
        content.body = cue.body
        content.sound = notificationSound(named: cue.soundName)

        let request = UNNotificationRequest(
            identifier: "eyepomo-sound-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func title(for kind: OverlayKind) -> String {
        switch kind {
        case .eyeBreak:
            return "该休息眼睛了"
        case .shortBreak:
            return "短休开始"
        case .longBreak:
            return "长休开始"
        }
    }

    private func notificationSound(named soundName: String) -> UNNotificationSound {
        UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(soundName).caf"))
    }
}
