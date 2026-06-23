import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    var isWindowVisibleForDiagnostics: Bool {
        window?.isVisible == true
    }

    func show(coordinator: AppCoordinator) {
        NSApp.setActivationPolicy(.regular)

        if let window {
            window.title = title(for: coordinator.appSettings.language)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView(coordinator: coordinator))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title(for: coordinator.appSettings.language)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = NSColor(
            calibratedRed: 28 / 255,
            green: 28 / 255,
            blue: 30 / 255,
            alpha: 1
        )
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 620, height: 560)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentViewController = hostingController
        window.center()
        window.delegate = self
        self.window = window

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    func closeForDiagnostics() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }

    private func title(for language: SettingsLanguage) -> String {
        switch language {
        case .chinese:
            return "EyePomo 设置"
        case .english:
            return "EyePomo Settings"
        }
    }
}
