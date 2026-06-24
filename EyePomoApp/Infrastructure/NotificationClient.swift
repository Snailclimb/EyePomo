import EyePomoCore
import Foundation
import UserNotifications

final class NotificationClient {
    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    func requestAuthorizationIfNeeded() {
        guard isAvailable else {
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func deliverOverlayNotification(_ request: OverlayRequest) {
        guard isAvailable else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title(for: request.kind)
        content.body = request.message
        content.sound = .default

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
}
