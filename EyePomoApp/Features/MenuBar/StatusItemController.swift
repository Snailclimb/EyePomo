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
        Appearance.apply(coordinator.appSettings.appearance, toPopover: popover)

        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
    }

    var isInstalledForDiagnostics: Bool {
        statusItem.button != nil
    }

    /// 运行时切换外观模式时，更新菜单栏 popover。
    func applyAppearance(_ mode: AppearanceMode) {
        Appearance.apply(mode, toPopover: popover)
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
            showMenu(from: sender)
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            Appearance.apply(coordinator.appSettings.appearance, toPopover: popover)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem(localized("暂停提醒 1 小时", "Pause for 1 Hour"), action: #selector(pauseForOneHour)))
        menu.addItem(menuItem(localized("今日不再提醒", "Mute for Today"), action: #selector(muteToday)))
        menu.addItem(.separator())
        menu.addItem(menuItem(localized("关于 EyePomo", "About EyePomo"), action: #selector(openAbout)))
        menu.addItem(menuItem(localized("设置…", "Settings…"), action: #selector(openSettings)))
        menu.addItem(menuItem(localized("打开日志目录", "Open Logs Folder"), action: #selector(openLogs)))
        menu.addItem(.separator())
        menu.addItem(menuItem(localized("退出 EyePomo", "Quit EyePomo"), action: #selector(quit)))

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
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

    @objc private func openAbout() {
        coordinator.showAbout()
    }

    @objc private func openLogs() {
        coordinator.openLogsDirectory()
    }

    @objc private func quit() {
        coordinator.quit()
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        coordinator.appSettings.language == .english ? english : chinese
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
