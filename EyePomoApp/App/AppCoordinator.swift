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
    private lazy var statusItemController = StatusItemController(coordinator: self)
    private let settingsWindowController = SettingsWindowController()

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        self.calendar = calendar

        let now = Self.makeInstant()
        let preferences = AppPreferences()
        self.currentInstant = now
        self.state = AppState.initial(now: now, preferences: preferences)
        self.todaySummary = DailySummary(dayKey: WorkHoursPolicy.dayKey(Date(), calendar: calendar))
    }

    func start() {
        AppPaths.ensureBaseDirectories()
        statusItemController.install()
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
    }

    func send(_ action: UserAction) {
        dispatch(.user(action))
    }

    func updatePreferences(_ preferences: AppPreferences) {
        dispatch(.user(.updatePreferences(preferences)))
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
            case .showOverlay:
                break
            case .dismissOverlay:
                break
            case .appendEvent:
                break
            case .persistState:
                break
            case .regenerateJournal:
                break
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
}
