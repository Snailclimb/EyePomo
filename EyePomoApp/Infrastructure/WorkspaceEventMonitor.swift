import AppKit
import EyePomoCore
import Foundation

@MainActor
final class WorkspaceEventMonitor {
    private let handler: (AppEvent) -> Void
    private var observers: [Any] = []

    init(handler: @escaping (AppEvent) -> Void) {
        self.handler = handler
    }

    func start() {
        stop()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handler(.presence(.sleepStarted)) }
        })
        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handler(.presence(.wakeDetected)) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handler(.system(.screensChanged)) }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handler(.presence(.screenLocked)) }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handler(.presence(.screenUnlocked)) }
        })
    }

    func stop() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in observers {
            workspaceCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observers.removeAll()
    }
}
