import AppKit
import Combine
import Darwin
import EyePomoCore
import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var currentInstant: AppInstant
    @Published private(set) var todaySummary: DailySummary
    @Published private(set) var appSettings: AppSettings

    private var calendar: Calendar
    private var dataPaths: AppPaths
    private var timer: Timer?
    private let settingsStore = SettingsStore()
    private let appSettingsStore = AppSettingsStore()
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

        let appSettings = AppSettingsStore().load() ?? AppSettings()
        let dataPaths = AppPaths(applicationSupportDirectory: appSettings.dataDirectoryURL)
        let now = Self.makeInstant()
        let preferences = SettingsStore().load() ?? AppPreferences()
        var restoredState = AppStateStore().load(now: now, wallDate: Date(), paths: dataPaths) ?? AppState.initial(now: now, preferences: preferences)
        restoredState.preferences = preferences
        self.appSettings = appSettings
        self.dataPaths = dataPaths
        self.currentInstant = now
        self.state = restoredState
        self.todaySummary = DailySummary(dayKey: WorkHoursPolicy.dayKey(Date(), calendar: calendar))
    }

    func start() {
        try? dataPaths.ensureBaseDirectories()
        settingsStore.save(state.preferences)
        appSettingsStore.save(appSettings)
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

        runUIDiagnosticsIfRequested()
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        idleMonitor?.stop()
        workspaceEventMonitor?.stop()
        stateStore.save(state, now: currentInstant, wallDate: Date(), paths: dataPaths)
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

    var dataDirectoryPath: String {
        dataPaths.applicationSupportDirectory.path
    }

    var logsDirectoryPath: String {
        dataPaths.logsDirectory.path
    }

    func setSettingsLanguage(_ language: SettingsLanguage) {
        guard appSettings.language != language else {
            return
        }

        var settings = appSettings
        settings.language = language
        appSettings = settings
        appSettingsStore.save(settings)
    }

    func showSettings() {
        settingsWindowController.show(coordinator: self)
    }

    func chooseDataDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = dataPaths.applicationSupportDirectory
        panel.title = appSettings.language == .english ? "Choose Data Folder" : "选择数据存储文件夹"
        panel.message = appSettings.language == .english
            ? "EyePomo will create Logs and Journals folders inside the selected folder."
            : "EyePomo 会在所选文件夹内创建 Logs 和 Journals 子目录。"
        panel.prompt = appSettings.language == .english ? "Use Folder" : "使用此文件夹"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        updateDataDirectory(url, usesDefaultDirectory: false)
    }

    func resetDataDirectoryToDefault() {
        updateDataDirectory(AppPaths.defaultApplicationSupportDirectory, usesDefaultDirectory: true)
    }

    func openDataDirectory() {
        try? dataPaths.ensureBaseDirectories()
        NSWorkspace.shared.activateFileViewerSelecting([dataPaths.applicationSupportDirectory])
    }

    func openLogsDirectory() {
        try? dataPaths.ensureBaseDirectories()
        NSWorkspace.shared.activateFileViewerSelecting([dataPaths.logsDirectory])
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func updateDataDirectory(_ url: URL, usesDefaultDirectory: Bool) {
        let newPaths = AppPaths(applicationSupportDirectory: url)

        do {
            stateStore.save(state, now: currentInstant, wallDate: Date(), paths: dataPaths)
            try copyExistingDataIfNeeded(to: newPaths)

            var settings = appSettings
            settings.customDataDirectoryPath = usesDefaultDirectory ? nil : newPaths.applicationSupportDirectory.path
            appSettings = settings
            dataPaths = newPaths
            appSettingsStore.save(settings)
            stateStore.save(state, now: currentInstant, wallDate: Date(), paths: dataPaths)
            refreshSummaryAndJournal(for: Date())
        } catch {
            showDataDirectoryError(error)
        }
    }

    private func copyExistingDataIfNeeded(to newPaths: AppPaths) throws {
        let oldRoot = dataPaths.applicationSupportDirectory.resolvingSymlinksInPath()
        let newRoot = newPaths.applicationSupportDirectory.resolvingSymlinksInPath()

        if oldRoot.path == newRoot.path {
            try newPaths.ensureBaseDirectories()
            return
        }

        if isDescendant(newRoot, of: oldRoot) {
            throw dataDirectoryError(
                chinese: "新的数据目录不能放在当前数据目录内部，请选择另一个文件夹。",
                english: "The new data folder cannot be inside the current data folder. Choose another folder."
            )
        }

        try newPaths.ensureBaseDirectories()
        guard FileManager.default.fileExists(atPath: oldRoot.path) else {
            return
        }
        try copyDirectoryContents(from: oldRoot, to: newRoot)
    }

    private func copyDirectoryContents(from source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let urls = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey])

        for url in urls {
            let target = destination.appendingPathComponent(url.lastPathComponent)
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                try copyDirectoryContents(from: url, to: target)
            } else if !FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.copyItem(at: url, to: target)
            }
        }
    }

    private func isDescendant(_ child: URL, of parent: URL) -> Bool {
        let childComponents = child.standardizedFileURL.pathComponents
        let parentComponents = parent.standardizedFileURL.pathComponents
        return childComponents.count > parentComponents.count
            && childComponents.prefix(parentComponents.count).elementsEqual(parentComponents)
    }

    private func dataDirectoryError(chinese: String, english: String) -> NSError {
        NSError(
            domain: "EyePomo.DataDirectory",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: appSettings.language == .english ? english : chinese]
        )
    }

    private func showDataDirectoryError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = appSettings.language == .english ? "Could Not Change Data Folder" : "无法切换数据目录"
        alert.informativeText = error.localizedDescription
        alert.runModal()
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
                stateStore.save(state, now: currentInstant, wallDate: Date(), paths: dataPaths)
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
        let paths = dataPaths
        Task { [eventStore] in
            try? await eventStore.append(event, paths: paths)
            let summary = try? await eventStore.regenerateJournal(for: event.occurredAt, preferences: preferences, calendar: calendar, paths: paths)
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
        let paths = dataPaths
        Task { [eventStore] in
            let summary = try? await eventStore.regenerateJournal(for: date, preferences: preferences, calendar: calendar, paths: paths)
            await MainActor.run {
                if let summary {
                    self.todaySummary = summary
                }
            }
        }
    }

    private func runUIDiagnosticsIfRequested() {
        guard CommandLine.arguments.contains("--run-ui-diagnostics") else {
            return
        }

        Task { @MainActor in
            let originalPreferences = state.preferences
            let originalAppSettings = appSettings
            let originalDataPaths = dataPaths
            let diagnosticDataRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("EyePomoUIDiagnostics-\(UUID().uuidString)", isDirectory: true)

            dataPaths = AppPaths(applicationSupportDirectory: diagnosticDataRoot)
            appSettings = AppSettings(
                language: originalAppSettings.language,
                customDataDirectoryPath: diagnosticDataRoot.path
            )
            try? dataPaths.ensureBaseDirectories()

            @MainActor
            func restoreDiagnosticsState() {
                overlayWindowController.dismiss()
                settingsWindowController.closeForDiagnostics()
                state.preferences = originalPreferences
                appSettings = originalAppSettings
                dataPaths = originalDataPaths
                settingsStore.save(originalPreferences)
                appSettingsStore.save(originalAppSettings)
                try? FileManager.default.removeItem(at: diagnosticDataRoot)
            }

            var failures: [String] = []
            print("EyePomo UI diagnostics started")

            if !statusItemController.isInstalledForDiagnostics {
                failures.append("status item button was not installed")
            }

            var diagnosticPreferences = state.preferences
            diagnosticPreferences.eyeBreakEnabled = true
            diagnosticPreferences.overlayEnabled = true
            diagnosticPreferences.notificationsEnabled = false
            diagnosticPreferences.workHoursEnabled = false
            updatePreferences(diagnosticPreferences)
            try? await Task.sleep(nanoseconds: 250_000_000)

            showSettings()
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !settingsWindowController.isWindowVisibleForDiagnostics {
                failures.append("settings window did not become visible")
            }

            send(.requestEyeBreakNow)
            try? await Task.sleep(nanoseconds: 500_000_000)
            let expectedPanels = max(1, NSScreen.screens.count)
            if overlayWindowController.visiblePanelCountForDiagnostics < expectedPanels {
                failures.append("eye break overlay did not create panels for active screens")
            }

            send(.snoozeEyeBreak)
            try? await Task.sleep(nanoseconds: 250_000_000)
            if overlayWindowController.visiblePanelCountForDiagnostics != 0 {
                failures.append("eye break overlay did not dismiss after snooze")
            }

            send(.startPomodoro)
            send(.pausePomodoro)
            send(.resumePomodoro)
            if state.pomodoro.runState != .running || state.pomodoro.phase != .focus {
                failures.append("pomodoro did not survive start/pause/resume diagnostics")
            }

            send(.skipPomodoroPhase)
            try? await Task.sleep(nanoseconds: 250_000_000)
            if !state.pomodoro.isBreak {
                failures.append("skip from focus did not enter a pomodoro break")
            }
            send(.endPomodoroBreak)

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let paths = dataPaths
            let logFiles = ((try? FileManager.default.contentsOfDirectory(at: paths.logsDirectory, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == "jsonl" }
            let journalFiles = ((try? FileManager.default.contentsOfDirectory(at: paths.journalsDirectory, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == "md" }
            if logFiles.isEmpty {
                failures.append("no JSONL event log was written")
            }
            if journalFiles.isEmpty {
                failures.append("no Markdown journal was written")
            }

            restoreDiagnosticsState()

            if failures.isEmpty {
                print("EyePomo UI diagnostics passed")
                Darwin.exit(0)
            } else {
                for failure in failures {
                    fputs("EyePomo UI diagnostics failure: \(failure)\n", stderr)
                }
                Darwin.exit(1)
            }
        }
    }
}
