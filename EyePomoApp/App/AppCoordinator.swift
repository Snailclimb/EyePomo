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
    private let eyeBreakOverlayWindowController = EyeBreakOverlayWindowController()
    private let eyeCareFilterController = EyeCareFilterController()
    private let notificationClient = NotificationClient()
    private let soundPlayer = SoundPlayer()
    private lazy var statusItemController = StatusItemController(coordinator: self)
    private let settingsWindowController = SettingsWindowController()
    private var idleMonitor: IdleMonitor?
    private var workspaceEventMonitor: WorkspaceEventMonitor?
    private var appearanceObserver: NSKeyValueObservation?
    private var pendingPreferenceCommit: AppPreferences?
    private var preferenceCommitTask: Task<Void, Never>?
    private var lastCommittedPreferences: AppPreferences

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
        self.lastCommittedPreferences = preferences
        syncAppearanceGlobals()
    }

    func start() {
        try? dataPaths.ensureBaseDirectories()
        settingsStore.save(state.preferences)
        appSettingsStore.save(appSettings)
        if state.preferences.notificationsEnabled {
            if notificationClient.isAvailable {
                notificationClient.requestAuthorizationIfNeeded()
            } else {
                state.preferences.notificationsEnabled = false
                settingsStore.save(state.preferences)
            }
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
        applyEyeCareFilter()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.handleSystemAppearanceChange()
            }
        }

        runUIDiagnosticsIfRequested()
    }

    func shutdown() {
        flushPendingPreferenceChanges()
        timer?.invalidate()
        timer = nil
        idleMonitor?.stop()
        workspaceEventMonitor?.stop()
        if let appearanceObserver {
            appearanceObserver.invalidate()
            self.appearanceObserver = nil
        }
        stateStore.save(state, now: currentInstant, wallDate: Date(), paths: dataPaths)
    }

    func send(_ action: UserAction) {
        dispatch(.user(action))
    }

    func updatePreferences(_ preferences: AppPreferences) {
        if preferences == state.preferences,
           pendingPreferenceCommit == nil || pendingPreferenceCommit == preferences {
            return
        }

        dispatch(.user(.previewPreferences(preferences)))
        schedulePreferenceCommit(preferences)
    }

    func flushPendingPreferenceChanges() {
        preferenceCommitTask?.cancel()
        preferenceCommitTask = nil

        guard let preferences = pendingPreferenceCommit else {
            return
        }

        pendingPreferenceCommit = nil
        commitPreferencesIfNeeded(preferences)
    }

    private func schedulePreferenceCommit(_ preferences: AppPreferences) {
        pendingPreferenceCommit = preferences
        preferenceCommitTask?.cancel()
        preferenceCommitTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                self?.flushPendingPreferenceChanges()
            }
        }
    }

    private func commitPreferencesIfNeeded(_ preferences: AppPreferences) {
        guard preferences != lastCommittedPreferences else {
            return
        }

        dispatch(.user(.commitPreferences(preferences)))
        lastCommittedPreferences = preferences
    }

    private func discardPendingPreferenceChanges(committed preferences: AppPreferences) {
        preferenceCommitTask?.cancel()
        preferenceCommitTask = nil
        pendingPreferenceCommit = nil
        lastCommittedPreferences = preferences
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        var preferences = state.preferences
        preferences.launchAtLogin = enabled
        LaunchAtLoginService.setEnabled(enabled)
        updatePreferences(preferences)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        var preferences = state.preferences
        if enabled {
            guard notificationClient.isAvailable else {
                preferences.notificationsEnabled = false
                updatePreferences(preferences)
                showNotificationUnavailable()
                return
            }

            preferences.notificationsEnabled = true
            notificationClient.requestAuthorizationIfNeeded()
        } else {
            preferences.notificationsEnabled = false
        }
        updatePreferences(preferences)
    }

    var dataDirectoryPath: String {
        dataPaths.applicationSupportDirectory.path
    }

    var logsDirectoryPath: String {
        dataPaths.logsDirectory.path
    }

    var summariesDirectoryPath: String {
        dataPaths.summariesDirectory.path
    }

    var currentMonthJournalPath: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM"
        let monthKey = formatter.string(from: Date())
        return dataPaths.journalsDirectory
            .appendingPathComponent("\(monthKey).md")
            .path
    }

    var currentMonthJournalExists: Bool {
        FileManager.default.fileExists(atPath: currentMonthJournalPath)
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

    func setAppearance(_ mode: AppearanceMode) {
        guard appSettings.appearance != mode else {
            return
        }

        var settings = appSettings
        settings.appearance = mode
        appSettings = settings
        appSettingsStore.save(settings)
        applyAppearanceAcrossWindows()
    }

    func setFontScale(_ scale: FontScale) {
        guard appSettings.fontScale != scale else {
            return
        }

        var settings = appSettings
        settings.fontScale = scale
        appSettings = settings
        AppFont.scale = scale.multiplier
        appSettingsStore.save(settings)
    }

    func setAccentPalette(_ palette: AccentPalette) {
        guard appSettings.accentPalette != palette else {
            return
        }

        var settings = appSettings
        settings.accentPalette = palette
        appSettings = settings
        AppPalette.current = palette
        appSettingsStore.save(settings)
    }

    func setDensity(_ density: AppDensity) {
        guard appSettings.density != density else {
            return
        }

        var settings = appSettings
        settings.density = density
        appSettings = settings
        AppDensityProfile.current = density
        appSettingsStore.save(settings)
    }

    func setEyeCareFilterEnabled(_ enabled: Bool) {
        var preferences = state.preferences
        preferences.eyeCareFilterEnabled = enabled
        updatePreferences(preferences)
        eyeCareFilterController.update(enabled: enabled, strength: preferences.eyeCareFilterStrength)
    }

    func setEyeCareFilterStrength(_ strength: Double) {
        var preferences = state.preferences
        preferences.eyeCareFilterStrength = strength
        updatePreferences(preferences)
        if preferences.eyeCareFilterEnabled {
            eyeCareFilterController.update(enabled: true, strength: strength)
        }
    }

    /// 按 preferences 同步护眼滤镜显示状态。
    private func applyEyeCareFilter() {
        eyeCareFilterController.update(
            enabled: state.preferences.eyeCareFilterEnabled,
            strength: state.preferences.eyeCareFilterStrength
        )
    }

    /// 将外观相关全局值（字号、强调色、密度）同步到当前 `appSettings`。
    private func syncAppearanceGlobals() {
        AppFont.scale = appSettings.fontScale.multiplier
        AppPalette.current = appSettings.accentPalette
        AppDensityProfile.current = appSettings.density
    }

    /// 将外观模式应用到所有已显示的 AppKit 容器（settings 窗口、菜单栏 popover、眼休遮罩）。
    private func applyAppearanceAcrossWindows() {
        let mode = appSettings.appearance
        settingsWindowController.applyAppearance(mode)
        statusItemController.applyAppearance(mode)
        eyeBreakOverlayWindowController.applyAppearance(mode)
    }

    private func handleSystemAppearanceChange() {
        guard appSettings.appearance == .system else {
            return
        }
        applyAppearanceAcrossWindows()
        // 系统外观变化不会改变 appSettings，手动通知 SwiftUI 重新解析
        // preferredColorScheme（其依赖的系统外观已变）。
        objectWillChange.send()
    }

    func showSettings() {
        settingsWindowController.show(coordinator: self)
    }

    func showAbout() {
        let panelOptions: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "EyePomo",
            .applicationVersion: appVersionString,
            .version: appBuildString,
            .credits: aboutCredits
        ]

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: panelOptions)
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
            ? "EyePomo will create Logs, Journals, and Summaries folders inside the selected folder."
            : "EyePomo 会在所选文件夹内创建 Logs、Journals 和 Summaries 子目录。"
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

    func openSummariesDirectory() {
        try? dataPaths.ensureBaseDirectories()
        NSWorkspace.shared.activateFileViewerSelecting([dataPaths.summariesDirectory])
    }

    func regenerateCurrentMonthJournal() {
        refreshSummaryAndJournal(for: Date())
    }

    func openJournalFile(at path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// Builds the last `dayCount` daily summaries on demand for trend views.
    /// Runs off the main actor because event log parsing can be heavy.
    func loadRecentSummaries(dayCount: Int) async -> [DailySummary] {
        let paths = dataPaths
        let calendar = calendar
        return await Task.detached(priority: .userInitiated) { [eventStore] in
            await eventStore.loadDailySummaries(
                endingAt: Date(),
                dayCount: dayCount,
                calendar: calendar,
                paths: paths
            )
        }.value
    }

    /// Loads every daily summary in the given Gregorian year, keyed by `dayKey`.
    /// Used by the year heatmap and yearly aggregate cards.
    func loadSummaries(forYear year: Int) async -> [String: DailySummary] {
        let paths = dataPaths
        let calendar = calendar
        return await Task.detached(priority: .userInitiated) { [eventStore] in
            await eventStore.loadSummaries(forYear: year, calendar: calendar, paths: paths)
        }.value
    }

    /// Loads every daily summary in a specific month, keyed by `dayKey`.
    func loadSummaries(forMonth month: Int, ofYear year: Int) async -> [String: DailySummary] {
        let paths = dataPaths
        let calendar = calendar
        return await Task.detached(priority: .userInitiated) { [eventStore] in
            await eventStore.loadSummaries(forMonth: month, ofYear: year, calendar: calendar, paths: paths)
        }.value
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

    private func showNotificationUnavailable() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = appSettings.language == .english ? "Notifications Need an App Bundle" : "系统通知需要 App Bundle"
        alert.informativeText = appSettings.language == .english
            ? "macOS UserNotifications is unavailable when EyePomo is launched with swift run. Run the built .app from Xcode or Finder to test notifications."
            : "通过 swift run 启动时，macOS UserNotifications 不可用。请从 Xcode 或 Finder 运行构建出的 .app 来测试系统通知。"
        alert.runModal()
    }

    var appVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    }

    var appBuildString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var aboutCredits: NSAttributedString {
        NSAttributedString(string: appSettings.language == .english
            ? "A lightweight menu bar app for eye breaks and Pomodoro focus.\nData stays on this Mac."
            : "一款轻量菜单栏应用，用于眼休提醒和番茄钟专注。\n数据仅保存在本机。")
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
                if request.kind == .eyeBreak, state.preferences.eyeBreakOverlayEnabled {
                    eyeBreakOverlayWindowController.show(request: request, coordinator: self)
                } else {
                    eyeBreakOverlayWindowController.dismiss()
                }
                if state.preferences.notificationsEnabled {
                    notificationClient.deliverOverlayNotification(request)
                }
            case .showPreReminder(let request):
                if state.preferences.notificationsEnabled {
                    notificationClient.deliverPreReminderNotification(request)
                }
            case .dismissOverlay:
                eyeBreakOverlayWindowController.dismiss()
            case .appendEvent(let event):
                appendEventAndRefresh(event)
                playSoundIfNeeded(for: event)
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

    private func playSoundIfNeeded(for event: EventEnvelope) {
        guard shouldPlayAudibleCue() else {
            return
        }

        let soundName: String?
        switch event.kind {
        case .eyeBreakDue:
            soundName = AppSoundCatalog.normalizedName(
                state.preferences.soundName,
                fallback: AppSoundCatalog.breakStartDefault
            )
        case .pomodoroFocusCompleted:
            soundName = AppSoundCatalog.focusCompleteDefault
        case .pomodoroBreakCompleted:
            soundName = AppSoundCatalog.breakCompleteDefault
        default:
            soundName = nil
        }

        guard let soundName else {
            return
        }

        soundPlayer.play(name: soundName, volume: state.preferences.soundVolume)
    }

    private func shouldPlayAudibleCue() -> Bool {
        let preferences = state.preferences
        guard preferences.soundEnabled else {
            return false
        }
        if preferences.respectSystemFocus, !preferences.notificationsEnabled {
            return false
        }
        guard !state.suppression.isPresentationModeActive(at: Date()) else {
            return false
        }
        guard !(preferences.reduceFullscreenInterruptions && state.suppression.isFullscreenActive) else {
            return false
        }
        guard WorkHoursPolicy.isInsideWorkHours(Date(), calendar: calendar, preferences: preferences) else {
            return false
        }
        return true
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
                eyeBreakOverlayWindowController.dismiss()
                eyeCareFilterController.hide()
                discardPendingPreferenceChanges(committed: originalPreferences)
                settingsWindowController.closeForDiagnostics()
                state.preferences = originalPreferences
                appSettings = originalAppSettings
                dataPaths = originalDataPaths
                syncAppearanceGlobals()
                applyEyeCareFilter()
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
            diagnosticPreferences.eyeBreakOverlayEnabled = true
            diagnosticPreferences.notificationsEnabled = false
            diagnosticPreferences.workHoursEnabled = false
            diagnosticPreferences.eyeCareFilterStrength = 0.18
            updatePreferences(diagnosticPreferences)
            setEyeCareFilterEnabled(true)
            try? await Task.sleep(nanoseconds: 250_000_000)

            showSettings()
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !settingsWindowController.isWindowVisibleForDiagnostics {
                failures.append("settings window did not become visible")
            }

            let expectedPanels = max(1, NSScreen.screens.count)
            if eyeCareFilterController.visiblePanelCountForDiagnostics < expectedPanels {
                failures.append("eye care filter did not create panels for active screens")
            }

            setEyeCareFilterEnabled(false)
            try? await Task.sleep(nanoseconds: 250_000_000)
            if eyeCareFilterController.visiblePanelCountForDiagnostics != 0 {
                failures.append("eye care filter did not hide after disabling")
            }

            send(.requestEyeBreakNow)
            try? await Task.sleep(nanoseconds: 250_000_000)
            if state.presentation.activeOverlay != .eyeBreak {
                failures.append("manual eye break did not enter active eye-break state")
            }
            if eyeBreakOverlayWindowController.visiblePanelCountForDiagnostics < expectedPanels {
                failures.append("eye-break overlay did not create panels for active screens")
            }

            send(.snoozeEyeBreak)
            try? await Task.sleep(nanoseconds: 250_000_000)
            if state.presentation.activeOverlay != nil {
                failures.append("snooze did not clear active eye-break state")
            }
            if eyeBreakOverlayWindowController.visiblePanelCountForDiagnostics != 0 {
                failures.append("eye-break overlay did not dismiss after snooze")
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
            let summaryFiles = ((try? FileManager.default.contentsOfDirectory(at: paths.summariesDirectory, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == "json" }
            if logFiles.isEmpty {
                failures.append("no JSONL event log was written")
            }
            if journalFiles.isEmpty {
                failures.append("no Markdown journal was written")
            }
            if summaryFiles.isEmpty {
                failures.append("no summary cache was written")
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
