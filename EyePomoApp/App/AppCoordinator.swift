import AppKit
import Combine
import EyePomoCore
import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var currentInstant: AppInstant
    @Published private(set) var todaySummary: DailySummary

    private var calendar: Calendar
    private var timer: Timer?
    private let settingsStore = SettingsStore()
    private let stateStore = AppStateStore()
    private let eventStore = EventStore()
    private let overlayWindowController = OverlayWindowController()
    private let notificationClient = NotificationClient()
    private lazy var statusItemController = StatusItemController(coordinator: self)
    private let settingsWindowController = SettingsWindowController()
    private var idleMonitor: IdleMonitor?
    private var workspaceEventMonitor: WorkspaceEventMonitor?

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        self.calendar = calendar

        let now = Self.makeInstant()
        let preferences = settingsStore.load() ?? AppPreferences()
        var restoredState = stateStore.load(now: now, wallDate: Date()) ?? AppState.initial(now: now, preferences: preferences)
        restoredState.preferences = preferences
        self.currentInstant = now
        self.state = restoredState
        self.todaySummary = DailySummary(dayKey: WorkHoursPolicy.dayKey(Date(), calendar: calendar))
    }

    func start() {
        AppPaths.ensureBaseDirectories()
        settingsStore.save(state.preferences)
        if state.preferences.notificationsEnabled {
            notificationClient.requestAuthorizationIfNeeded()
        }
        statusItemController.install()
        idleMonitor = IdleMonitor(
            threshold: { [weak self] in self?.state.preferences.idleThresholdSeconds ?? 180 },
            handler: { [weak self] event in self?.dispatch(.presence(event)) }
        )
        workspaceEventMonitor = WorkspaceEventMonitor { [weak self] event in
            self?.dispatch(event)
        }
        idleMonitor?.start()
        workspaceEventMonitor?.start()
        refreshSummaryAndJournal(for: Date())
        refreshChrome()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        idleMonitor?.stop()
        workspaceEventMonitor?.stop()
        stateStore.save(state, now: currentInstant, wallDate: Date())
    }

    func send(_ action: UserAction) {
        dispatch(.user(action))
    }

    func updatePreferences(_ preferences: AppPreferences) {
        dispatch(.user(.updatePreferences(preferences)))
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        var preferences = state.preferences
        preferences.launchAtLogin = enabled
        LaunchAtLoginService.setEnabled(enabled)
        updatePreferences(preferences)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        var preferences = state.preferences
        preferences.notificationsEnabled = enabled
        if enabled {
            notificationClient.requestAuthorizationIfNeeded()
        }
        updatePreferences(preferences)
    }

    func showSettings() {
        settingsWindowController.show(coordinator: self)
    }

    func openLogsDirectory() {
        AppPaths.ensureBaseDirectories()
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.logsDirectory])
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func tick() {
        dispatch(.clock(.tick))
    }

    private func dispatch(_ event: AppEvent) {
        currentInstant = Self.makeInstant()
        let effects = AppReducer.reduce(
            state: &state,
            event: event,
            now: currentInstant,
            wallDate: Date(),
            calendar: calendar
        )
        apply(effects)
        refreshChrome()
    }

    private func apply(_ effects: [AppEffect]) {
        for effect in effects {
            switch effect {
            case .updateStatusItem:
                break
            case .showOverlay(let request):
                if state.preferences.overlayEnabled {
                    overlayWindowController.show(request: request, coordinator: self)
                }
                if state.preferences.notificationsEnabled {
                    notificationClient.deliverOverlayNotification(request)
                }
            case .dismissOverlay:
                overlayWindowController.dismiss()
            case .appendEvent(let event):
                appendEventAndRefresh(event)
            case .persistState:
                settingsStore.save(state.preferences)
                stateStore.save(state, now: currentInstant, wallDate: Date())
            case .regenerateJournal(let date):
                refreshSummaryAndJournal(for: date)
            }
        }
    }

    private func refreshChrome() {
        currentInstant = Self.makeInstant()
        statusItemController.update(snapshot: state.displaySnapshot(at: currentInstant))
    }

    private static func makeInstant() -> AppInstant {
        AppInstant(milliseconds: Int64(ProcessInfo.processInfo.systemUptime * 1_000))
    }

    private func appendEventAndRefresh(_ event: EventEnvelope) {
        let preferences = state.preferences
        let calendar = calendar
        Task { [eventStore] in
            try? await eventStore.append(event)
            let summary = try? await eventStore.regenerateJournal(for: event.occurredAt, preferences: preferences, calendar: calendar)
            await MainActor.run {
                if let summary {
                    self.todaySummary = summary
                }
            }
        }
    }

    private func refreshSummaryAndJournal(for date: Date) {
        let preferences = state.preferences
        let calendar = calendar
        Task { [eventStore] in
            let summary = try? await eventStore.regenerateJournal(for: date, preferences: preferences, calendar: calendar)
            await MainActor.run {
                if let summary {
                    self.todaySummary = summary
                }
            }
        }
    }
}
