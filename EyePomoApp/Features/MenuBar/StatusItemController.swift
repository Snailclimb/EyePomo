import AppKit
import EyePomoCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private unowned let coordinator: AppCoordinator
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var latestSnapshot: DisplaySnapshot?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    func install() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.contentViewController = NSHostingController(rootView: MenuBarPanelView(coordinator: coordinator))

        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
    }

    func update(snapshot: DisplaySnapshot) {
        latestSnapshot = snapshot
        guard let button = statusItem.button else {
            return
        }
        button.image = icon(for: snapshot)
        button.image?.isTemplate = true
        button.title = title(for: snapshot)
        button.toolTip = "EyePomo \(snapshot.stateLabel) \(snapshot.countdown)"
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(menuItem("暂停提醒 1 小时", action: #selector(pauseForOneHour)))
        menu.addItem(menuItem("今日不再提醒", action: #selector(muteToday)))
        menu.addItem(.separator())
        menu.addItem(menuItem("打开设置", action: #selector(openSettings)))
        menu.addItem(menuItem("打开日志目录", action: #selector(openLogs)))
        menu.addItem(.separator())
        menu.addItem(menuItem("退出 EyePomo", action: #selector(quit)))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func pauseForOneHour() {
        coordinator.send(.pauseReminders(seconds: 3_600))
    }

    @objc private func muteToday() {
        coordinator.send(.muteRemindersForToday)
    }

    @objc private func openSettings() {
        coordinator.showSettings()
    }

    @objc private func openLogs() {
        coordinator.openLogsDirectory()
    }

    @objc private func quit() {
        coordinator.quit()
    }

    private func title(for snapshot: DisplaySnapshot) -> String {
        snapshot.statusTitle
            .replacingOccurrences(of: "🍅 ", with: "")
            .replacingOccurrences(of: "☕ ", with: "")
            .replacingOccurrences(of: "👁 ", with: "")
    }

    private func icon(for snapshot: DisplaySnapshot) -> NSImage? {
        let name: String
        switch snapshot.accent {
        case .tomato:
            name = "timer"
        case .teal:
            name = snapshot.stateLabel.contains("休") ? "cup.and.saucer" : "eye"
        case .neutral:
            name = "pause.circle"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: "EyePomo")
    }
}
