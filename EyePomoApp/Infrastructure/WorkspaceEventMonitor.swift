import AppKit
import EyePomoCore
import Foundation

@MainActor
final class WorkspaceEventMonitor {
    private let handler: (AppEvent) -> Void
    private var observers: [Any] = []
    private var lastFullscreenActive: Bool?

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
            Task { @MainActor in
                self?.handler(.system(.screensChanged))
                self?.emitFullscreenActivityIfNeeded()
            }
        })
        observers.append(workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.emitFullscreenActivityIfNeeded() }
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

        emitFullscreenActivityIfNeeded()
    }

    func stop() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in observers {
            workspaceCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observers.removeAll()
        lastFullscreenActive = nil
    }

    private func emitFullscreenActivityIfNeeded() {
        let isActive = Self.isFullscreenSpaceLikelyActive()
        guard lastFullscreenActive != isActive else {
            return
        }
        lastFullscreenActive = isActive
        handler(.system(.fullscreenActivityChanged(isActive: isActive)))
    }

    private static func isFullscreenSpaceLikelyActive() -> Bool {
        NSScreen.screens.contains { screen in
            let frame = screen.frame
            let visible = screen.visibleFrame
            return abs(frame.width - visible.width) <= 2
                && abs(frame.height - visible.height) <= 2
        }
    }
}
