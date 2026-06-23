import EyePomoCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var selectedTab: SettingsTab = .eye
    @State private var isRefreshingJournal = false
    @State private var trendSummaries: [DailySummary] = []
    @State private var dataScope: DataScope = .today
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var scopeSummaries: [String: DailySummary] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SettingsStyle.windowBackground, SettingsStyle.outerBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar
                tabToolbar
                ScrollView {
                    selectedContent
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .background(SettingsStyle.windowBackground)
        }
        .frame(minWidth: 620, minHeight: 560)
        .font(.system(size: 13))
        .foregroundStyle(SettingsStyle.primaryText)
        .onAppear {
            refreshTrendIfNeeded()
            refreshScopeSummariesIfNeeded()
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .data {
                refreshTrendIfNeeded()
                refreshScopeSummariesIfNeeded()
            }
        }
        .onChange(of: coordinator.todaySummary) { _ in
            if selectedTab == .data {
                refreshTrendIfNeeded()
                if dataScope == .today {
                    // Today is covered by `coordinator.todaySummary` directly.
                } else {
                    refreshScopeSummariesIfNeeded()
                }
            }
        }
        .onChange(of: dataScope) { _ in
            refreshScopeSummariesIfNeeded()
        }
        .onChange(of: selectedYear) { _ in
            refreshScopeSummariesIfNeeded()
        }
        .onChange(of: selectedMonth) { _ in
            refreshScopeSummariesIfNeeded()
        }
    }

    private func refreshTrendIfNeeded() {
        Task { @MainActor in
            let summaries = await coordinator.loadRecentSummaries(dayCount: 7)
            trendSummaries = summaries
        }
    }

    private func refreshScopeSummariesIfNeeded() {
        let scope = dataScope
        let year = selectedYear
        let month = selectedMonth
        Task { @MainActor in
            let summaries: [String: DailySummary]
            switch scope {
            case .today:
                summaries = [:]
            case .month:
                summaries = await coordinator.loadSummaries(forMonth: month, ofYear: year)
            case .year:
                summaries = await coordinator.loadSummaries(forYear: year)
            }
            scopeSummaries = summaries
        }
    }

    private var titleBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 72)
            Spacer()
            Text(localized("EyePomo 设置", "EyePomo Settings"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SettingsStyle.mutedText)
            Spacer()
            Color.clear.frame(width: 72)
        }
        .frame(height: 44)
        .background(SettingsStyle.titleBarBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SettingsStyle.divider)
                .frame(height: 1)
        }
    }

    private var tabToolbar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title(language: coordinator.appSettings.language))
                        .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                        .foregroundStyle(selectedTab == tab ? SettingsStyle.primaryText : SettingsStyle.mutedText)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selectedTab == tab ? Color.white.opacity(0.10) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(SettingsStyle.toolbarBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SettingsStyle.divider)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .eye:
            eyeTab
        case .pomodoro:
            pomodoroTab
        case .time:
            timeTab
        case .data:
            dataTab
        }
    }

    private var eyeTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup {
                SettingRow(localized("启用眼部提醒", "Enable eye reminders"), sub: localized("定时提醒你放松眼睛，遵循 20-20-20 法则", "Remind you to relax your eyes on a 20-20-20 cadence")) {
                    settingSwitch(boolBinding(\.eyeBreakEnabled))
                }
                SettingRow(localized("提醒间隔", "Reminder interval"), sub: localized("每隔多少分钟触发一次眼休", "How many minutes between eye breaks")) {
                    SettingStepper(value: minutesBinding(\.eyeBreakIntervalSeconds), range: 5...90, unit: localized("分钟", "min"))
                }
                SettingRow(localized("眼休时长", "Eye break duration"), sub: localized("每次眼休持续多少秒", "How many seconds each eye break lasts")) {
                    SettingStepper(value: secondsBinding(\.eyeBreakDurationSeconds), range: 10...120, unit: localized("秒", "sec"))
                }
                SettingRow(localized("稍后提醒", "Snooze"), sub: localized("临时推迟下一次眼休", "Temporarily delay the next eye break"), last: true) {
                    SettingStepper(value: minutesBinding(\.snoozeSeconds), range: 1...30, unit: localized("分钟", "min"))
                }
            }

            SettingGroup(localized("提醒方式", "Reminder style")) {
                SettingRow(localized("全屏覆盖层", "Full-screen overlay"), sub: localized("眼休时显示半透明全屏提醒界面", "Show a translucent full-screen rest overlay")) {
                    settingSwitch(boolBinding(\.overlayEnabled))
                }
                SettingRow(localized("系统通知", "System notifications"), sub: localized("允许通过 macOS 通知辅助提醒", "Use macOS notifications as a backup reminder"), last: true) {
                    settingSwitch(notificationsBinding)
                }
            }

            Text(localized("20-20-20 法则：每工作 20 分钟，看向至少 6 米外，持续 20 秒。有助于缓解数字眼疲劳。", "20-20-20 rule: every 20 minutes, look at something at least 20 feet away for 20 seconds. It can help reduce digital eye strain."))
                .font(.system(size: 11))
                .lineSpacing(3)
                .foregroundStyle(SettingsStyle.tertiaryText)
                .padding(.leading, 4)
        }
    }

    private var pomodoroTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup(localized("时长", "Durations")) {
                SettingRow(localized("专注时长", "Focus duration")) {
                    SettingStepper(value: minutesBinding(\.focusDurationSeconds), range: 5...90, unit: localized("分钟", "min"))
                }
                SettingRow(localized("短休息", "Short break")) {
                    SettingStepper(value: minutesBinding(\.shortBreakDurationSeconds), range: 1...30, unit: localized("分钟", "min"))
                }
                SettingRow(localized("长休息", "Long break"), last: true) {
                    SettingStepper(value: minutesBinding(\.longBreakDurationSeconds), range: 5...45, unit: localized("分钟", "min"))
                }
            }

            SettingGroup(localized("节奏", "Rhythm")) {
                SettingRow(localized("长休息间隔", "Long break cadence"), sub: localized("完成多少个番茄后进入长休息", "How many focus sessions before a long break"), last: true) {
                    SettingStepper(value: intBinding(\.longBreakEvery), range: 2...8, unit: localized("个", "sessions"))
                }
            }
        }
    }

    private var timeTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingGroup(localized("系统集成", "System integration")) {
                SettingRow(localized("登录时启动", "Launch at login"), sub: localized("macOS 启动后自动运行 EyePomo", "Start EyePomo automatically after macOS login")) {
                    settingSwitch(launchAtLoginBinding)
                }
                SettingRow(localized("系统通知", "System notifications"), sub: localized("允许休息提醒出现在通知中心", "Allow rest reminders in Notification Center"), last: true) {
                    settingSwitch(notificationsBinding)
                }
            }

            SettingGroup(localized("工作时段", "Work hours")) {
                SettingRow(localized("启用工作时段限制", "Limit to work hours"), sub: localized("非工作时段不自动弹出眼休遮罩", "Do not show eye-break overlays outside work hours")) {
                    settingSwitch(boolBinding(\.workHoursEnabled))
                }
                SettingRow(localized("开始时间", "Start time")) {
                    SettingStepper(value: hourBinding(\.workStartMinuteOfDay), range: 0...23, unit: localized("点", ":00"))
                }
                SettingRow(localized("结束时间", "End time")) {
                    SettingStepper(value: hourBinding(\.workEndMinuteOfDay), range: 1...24, unit: localized("点", ":00"))
                }
                SettingRow(localized("空闲推测休息", "Infer idle rests"), sub: localized("超过阈值后重置眼休倒计时", "Reset the eye-break countdown after the idle threshold"), last: true) {
                    SettingStepper(value: minutesBinding(\.idleThresholdSeconds), range: 1...20, unit: localized("分钟", "min"))
                }
            }

            SettingGroup(localized("覆盖层", "Overlay")) {
                SettingRow(localized("遮罩透明度", "Overlay opacity"), sub: localized("调整休息遮罩的覆盖强度", "Adjust the visual strength of the rest overlay"), last: true) {
                    OpacityControl(value: opacityBinding)
                }
            }
        }
    }

    private var dataTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            statusBanner
            dataScopeToolbar
            countCardsRow
            durationCardsRow
            breakChartPanel
            trendPanel
            if dataScope == .year {
                yearHeatmapPanel
            }
            dataManagementGroup
            interfaceGroup

            footerRow
        }
    }

    private var dataScopeToolbar: some View {
        HStack(spacing: 10) {
            DataScopeSegmentedControl(
                selection: dataScope,
                language: coordinator.appSettings.language
            ) { newScope in
                dataScope = newScope
            }

            Spacer(minLength: 0)

            scopeSelector
        }
    }

    @ViewBuilder
    private var scopeSelector: some View {
        switch dataScope {
        case .today:
            EmptyView()
        case .month:
            MonthPicker(year: $selectedYear, month: $selectedMonth)
        case .year:
            YearStepper(year: $selectedYear, language: coordinator.appSettings.language)
        }
    }

    private var yearHeatmapPanel: some View {
        ChartPanel(
            title: localized("\(selectedYear) 年热力图", "\(selectedYear) Heatmap"),
            legend: [(localized("番茄数", "Pomodoros"), EyePomoTheme.teal)]
        ) {
            if scopeSummaries.isEmpty {
                emptyChartPlaceholder
            } else {
                YearHeatmapView(
                    year: selectedYear,
                    summaries: scopeSummaries,
                    reduceTransparency: reduceTransparency,
                    locale: coordinator.appSettings.language == .english
                        ? Locale(identifier: "en_US_POSIX")
                        : Locale(identifier: "zh_CN")
                )
            }
        }
    }

    private var statusBanner: some View {
        let snapshot = coordinator.state.displaySnapshot(at: coordinator.currentInstant)
        let accentColor = bannerColor(for: snapshot.accent)
        let isActive = snapshot.accent != .neutral
        return HStack(spacing: 14) {
            StatusDot(accent: accentColor, isActive: isActive, reduceMotion: reduceMotion)

            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle(for: snapshot))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SettingsStyle.primaryText)
                if !snapshot.countdown.isEmpty {
                    Text(snapshot.countdown)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(SettingsStyle.mutedText)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 0)

            StatusBar(value: snapshot.progress, accent: accentColor, reduceMotion: reduceMotion)
                .frame(width: 140)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(SettingsStyle.groupBackground(reduceTransparency: reduceTransparency))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var footerRow: some View {
        HStack(spacing: 12) {
            Text(localized("EyePomo \(coordinator.appVersionString) · 数据仅保存在本机，不会上传到任何服务器", "EyePomo \(coordinator.appVersionString) · Data stays on this Mac and is never uploaded to a server"))
                .font(.system(size: 11))
                .foregroundStyle(SettingsStyle.tertiaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Button {
                coordinator.showAbout()
            } label: {
                Label(localized("关于", "About"), systemImage: "info.circle")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SettingsStyle.actionBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, -4)
    }

    private func bannerColor(for accent: DisplayAccent) -> Color {
        switch accent {
        case .teal:
            return EyePomoTheme.teal
        case .tomato:
            return EyePomoTheme.tomato
        case .neutral:
            return SettingsStyle.mutedText
        }
    }

    private func bannerTitle(for snapshot: DisplaySnapshot) -> String {
        let language = coordinator.appSettings.language
        if language == .english {
            return snapshot.statusTitle
        }
        return snapshot.stateLabel.isEmpty ? snapshot.statusTitle : snapshot.stateLabel
    }

    private var countCardsRow: some View {
        let summary = displayedSummary
        return HStack(spacing: 8) {
            SummaryCard(
                label: cardLabel(localized("番茄", "Pomodoros")),
                value: "\(summary.focusSessionsCompleted)",
                unit: localized("个", "pomodoros"),
                color: EyePomoTheme.tomato
            )
            SummaryCard(
                label: cardLabel(localized("眼休完成", "Eye Breaks")),
                value: "\(summary.eyeBreaksCompleted)",
                unit: localized("次", "times"),
                color: EyePomoTheme.teal
            )
            SummaryCard(
                label: cardLabel(localized("跳过眼休", "Skipped")),
                value: "\(summary.eyeBreaksSkipped)",
                unit: localized("次", "times"),
                color: SettingsStyle.warningRed
            )
        }
    }

    private var durationCardsRow: some View {
        let summary = displayedSummary
        return HStack(spacing: 8) {
            SummaryCard(
                label: cardLabel(localized("专注时长", "Focus Time")),
                value: durationText(summary.focusMinutes * 60, preferMinutes: false),
                unit: durationUnitText(summary.focusMinutes),
                color: SettingsStyle.primaryText
            )
            SummaryCard(
                label: cardLabel(localized("推断休息", "Inferred Rests")),
                value: "\(summary.inferredRests)",
                unit: localized("次", "times"),
                color: EyePomoTheme.teal
            )
            SummaryCard(
                label: cardLabel(localized("最长连续使用", "Longest Stretch")),
                value: durationText(summary.longestContinuousUsageMinutes * 60, preferMinutes: true),
                unit: localized("分钟", "min"),
                color: SettingsStyle.actionBlue
            )
        }
    }

    /// Prefixes a card title with the current scope label, e.g. "今日 番茄"
    /// in Chinese or "Today · Pomodoros" in English. Reuses `localized` so
    /// both languages stay readable.
    private func cardLabel(_ base: String) -> String {
        let isEnglish = coordinator.appSettings.language == .english
        let prefix: String
        switch dataScope {
        case .today:
            prefix = isEnglish ? "Today" : "今日"
        case .month:
            prefix = isEnglish ? "Month" : "\(selectedMonth)月"
        case .year:
            prefix = isEnglish ? "\(selectedYear)" : "\(selectedYear)年"
        }
        return isEnglish ? "\(prefix) · \(base)" : "\(prefix) \(base)"
    }

    /// The summary currently shown in the cards. Today reads from the live
    /// `coordinator.todaySummary`; year and month aggregate the selected
    /// range from `scopeSummaries`.
    private var displayedSummary: DailySummary {
        switch dataScope {
        case .today:
            return coordinator.todaySummary
        case .month:
            return aggregateSummaries(
                in: scopeSummaries,
                dayKey: String(format: "%04d-%02d", selectedYear, selectedMonth)
            )
        case .year:
            return aggregateSummaries(
                in: scopeSummaries,
                dayKey: String(format: "%04d", selectedYear)
            )
        }
    }

    private func aggregateSummaries(in summaries: [String: DailySummary], dayKey: String) -> DailySummary {
        var combined = DailySummary(dayKey: dayKey)
        for summary in summaries.values {
            combined.focusSessionsCompleted += summary.focusSessionsCompleted
            combined.focusMinutes += summary.focusMinutes
            combined.eyeBreaksCompleted += summary.eyeBreaksCompleted
            combined.eyeBreaksSkipped += summary.eyeBreaksSkipped
            combined.inferredRests += summary.inferredRests
            // Across a multi-day range, "longest continuous usage" is the worst day.
            combined.longestContinuousUsageMinutes = max(
                combined.longestContinuousUsageMinutes,
                summary.longestContinuousUsageMinutes
            )
        }
        return combined
    }

    private var breakChartPanel: some View {
        let summary = displayedSummary
        let hasAnyCount = summary.focusSessionsCompleted > 0
            || summary.eyeBreaksCompleted > 0
            || summary.eyeBreaksSkipped > 0

        return ChartPanel(
            title: scopeCountsTitle,
            legend: [
                (localized("番茄", "Pomodoros"), EyePomoTheme.tomato),
                (localized("完成", "Done"), EyePomoTheme.teal),
                (localized("跳过", "Skipped"), SettingsStyle.warningRed)
            ]
        ) {
            if hasAnyCount {
                MiniBarChart(
                    bars: [
                        MiniBar(label: localized("番茄", "Pomodoros"), value: Double(summary.focusSessionsCompleted), color: EyePomoTheme.tomato),
                        MiniBar(label: localized("完成", "Done"), value: Double(summary.eyeBreaksCompleted), color: EyePomoTheme.teal),
                        MiniBar(label: localized("跳过", "Skipped"), value: Double(summary.eyeBreaksSkipped), color: SettingsStyle.warningRed)
                    ],
                    kind: .integer
                )
            } else {
                emptyChartPlaceholder
            }
        }
    }

    private var scopeCountsTitle: String {
        let scopeText: String
        switch dataScope {
        case .today:
            scopeText = todayDateString
        case .month:
            scopeText = String(format: "%04d-%02d", selectedYear, selectedMonth)
        case .year:
            scopeText = "\(selectedYear)"
        }
        return localized("计数（\(scopeText)）", "Counts (\(scopeText))")
    }

    private var emptyChartPlaceholder: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 18))
                .foregroundStyle(SettingsStyle.tertiaryText)
            Text(localized("暂无事件数据，完成一次番茄或眼休后这里会显示统计", "No event data yet. Stats appear after your first Pomodoro or eye break."))
                .font(.system(size: 11))
                .foregroundStyle(SettingsStyle.tertiaryText)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    private var trendPanel: some View {
        ChartPanel(
            title: localized("近 7 天番茄完成数", "Pomodoros — Last 7 Days"),
            legend: [(localized("完成", "Done"), EyePomoTheme.tomato)]
        ) {
            if trendSummaries.isEmpty {
                emptyChartPlaceholder
            } else {
                TrendBarChart(summaries: trendSummaries, color: EyePomoTheme.tomato, reduceMotion: reduceMotion)
            }
        }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.locale = coordinator.appSettings.language == .english
            ? Locale(identifier: "en_US_POSIX")
            : Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: Date())
    }

    private var dataManagementGroup: some View {
        SettingGroup(localized("数据管理", "Data management")) {
            SettingRow(localized("数据存储位置", "Data storage location"), sub: coordinator.dataDirectoryPath) {
                HStack(spacing: 8) {
                    DataActionButton(title: localized("选择", "Choose"), color: SettingsStyle.actionBlue) {
                        coordinator.chooseDataDirectory()
                    }
                    DataActionButton(title: localized("打开", "Open"), color: EyePomoTheme.teal) {
                        coordinator.openDataDirectory()
                    }
                }
            }
            SettingRow(localized("日志目录", "Log folder"), sub: coordinator.logsDirectoryPath) {
                DataActionButton(title: localized("打开", "Open"), color: SettingsStyle.actionBlue) {
                    coordinator.openLogsDirectory()
                }
            }
            SettingRow(
                localized("Markdown 摘要", "Markdown summaries"),
                sub: journalSubText,
                last: true
            ) {
                if isRefreshingJournal {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                        Text(localized("生成中", "Generating"))
                            .font(.system(size: 11))
                            .foregroundStyle(SettingsStyle.mutedText)
                    }
                    .frame(width: 96)
                } else {
                    DataActionButton(
                        title: coordinator.todayJournalExists
                            ? localized("打开", "Open")
                            : localized("生成", "Generate"),
                        color: EyePomoTheme.teal
                    ) {
                        if coordinator.todayJournalExists {
                            coordinator.openJournalFile(at: coordinator.todayJournalPath)
                        } else {
                            triggerJournalRefresh()
                        }
                    }
                }
            }
        }
    }

    private var journalSubText: String {
        if isRefreshingJournal {
            return localized("正在从事件日志重建摘要…", "Rebuilding summary from event logs…")
        }
        if coordinator.todayJournalExists {
            return coordinator.todayJournalPath
        }
        return localized("今日尚未生成摘要，完成任意一次眼休或番茄后自动生成", "No summary yet for today — it appears after the first eye break or Pomodoro")
    }

    private func triggerJournalRefresh() {
        guard !isRefreshingJournal else { return }
        isRefreshingJournal = true
        coordinator.regenerateTodayJournal()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            isRefreshingJournal = false
        }
    }

    private var interfaceGroup: some View {
        SettingGroup(localized("界面", "Interface")) {
            SettingRow(localized("显示语言", "Display language"), sub: localized("切换设置窗口的显示语言", "Switch the language used in this settings window"), last: true) {
                LanguageSegmentedControl(selection: languageBinding)
            }
        }
    }

    private func durationText(_ totalSeconds: Int, preferMinutes: Bool) -> String {
        let minutes = totalSeconds / 60
        if preferMinutes || minutes < 60 {
            return String(format: "%d", minutes)
        }
        let hours = Double(minutes) / 60
        return String(format: "%.1f", hours)
    }

    private func durationUnitText(_ totalMinutes: Int) -> String {
        totalMinutes < 60 ? localized("分钟", "min") : localized("小时", "h")
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<AppPreferences, Int>) -> Binding<Int> {
        Binding(
            get: { coordinator.state.preferences[keyPath: keyPath] / 60 },
            set: { newValue in
                var preferences = coordinator.state.preferences
                preferences[keyPath: keyPath] = newValue * 60
                coordinator.updatePreferences(preferences)
            }
        )
    }

    private func secondsBinding(_ keyPath: WritableKeyPath<AppPreferences, Int>) -> Binding<Int> {
        Binding(
            get: { coordinator.state.preferences[keyPath: keyPath] },
            set: { newValue in
                var preferences = coordinator.state.preferences
                preferences[keyPath: keyPath] = newValue
                coordinator.updatePreferences(preferences)
            }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<AppPreferences, Int>) -> Binding<Int> {
        Binding(
            get: { coordinator.state.preferences[keyPath: keyPath] },
            set: { newValue in
                var preferences = coordinator.state.preferences
                preferences[keyPath: keyPath] = newValue
                coordinator.updatePreferences(preferences)
            }
        )
    }

    private func hourBinding(_ keyPath: WritableKeyPath<AppPreferences, Int>) -> Binding<Int> {
        Binding(
            get: { coordinator.state.preferences[keyPath: keyPath] / 60 },
            set: { newValue in
                var preferences = coordinator.state.preferences
                preferences[keyPath: keyPath] = newValue * 60
                coordinator.updatePreferences(preferences)
            }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { coordinator.state.preferences[keyPath: keyPath] },
            set: { newValue in
                var preferences = coordinator.state.preferences
                preferences[keyPath: keyPath] = newValue
                coordinator.updatePreferences(preferences)
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { coordinator.state.preferences.launchAtLogin },
            set: { coordinator.setLaunchAtLogin($0) }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { coordinator.state.preferences.notificationsEnabled },
            set: { coordinator.setNotificationsEnabled($0) }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { coordinator.state.preferences.overlayOpacity },
            set: { newValue in
                var preferences = coordinator.state.preferences
                preferences.overlayOpacity = newValue
                coordinator.updatePreferences(preferences)
            }
        )
    }

    private var languageBinding: Binding<SettingsLanguage> {
        Binding(
            get: { coordinator.appSettings.language },
            set: { coordinator.setSettingsLanguage($0) }
        )
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        coordinator.appSettings.language == .english ? english : chinese
    }

    private func settingSwitch(_ binding: Binding<Bool>) -> SettingSwitch {
        SettingSwitch(
            isOn: binding,
            onLabel: localized("已启用", "On"),
            offLabel: localized("已关闭", "Off"),
            reduceMotion: reduceMotion
        )
    }
}

private enum SettingsTab: CaseIterable, Identifiable {
    case eye
    case pomodoro
    case time
    case data

    var id: Self { self }

    func title(language: SettingsLanguage) -> String {
        switch (self, language) {
        case (.eye, .chinese):
            return "护眼"
        case (.eye, .english):
            return "Eye Breaks"
        case (.pomodoro, .chinese):
            return "番茄钟"
        case (.pomodoro, .english):
            return "Pomodoro"
        case (.time, .chinese):
            return "时间与提醒"
        case (.time, .english):
            return "Time & Alerts"
        case (.data, .chinese):
            return "数据"
        case (.data, .english):
            return "Data"
        }
    }
}

enum SettingsStyle {
    static let outerBackground = Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255)
    static let windowBackground = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let titleBarBackground = Color(red: 38 / 255, green: 38 / 255, blue: 40 / 255).opacity(0.98)
    static let toolbarBackground = Color(red: 32 / 255, green: 32 / 255, blue: 34 / 255).opacity(0.95)
    static let divider = Color.white.opacity(0.07)
    static let rowDivider = Color.white.opacity(0.06)
    static let primaryText = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    static let mutedText = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let secondaryText = Color(red: 99 / 255, green: 99 / 255, blue: 102 / 255)
    static let tertiaryText = Color(red: 72 / 255, green: 72 / 255, blue: 74 / 255)
    static let actionBlue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let warningRed = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)
    static let monoFont = Font.system(size: 13, weight: .regular, design: .monospaced)

    /// Card / group background. macOS Reduce Transparency expects solid surfaces
    /// instead of half-alpha plates that leak desktop wallpaper through.
    static func groupBackground(reduceTransparency: Bool) -> Color {
        reduceTransparency
            ? Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
            : Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255).opacity(0.50)
    }
}

private struct SettingGroup<Content: View>: View {
    let title: String?
    let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SettingsStyle.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                content
            }
            .background(SettingsStyle.groupBackground(reduceTransparency: reduceTransparency))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct SettingRow<Trailing: View>: View {
    let label: String
    let sub: String?
    let last: Bool
    let trailing: Trailing

    init(_ label: String, sub: String? = nil, last: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.sub = sub
        self.last = last
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(SettingsStyle.primaryText)
                if let sub {
                    Text(sub)
                        .font(.system(size: 11))
                        .lineSpacing(2)
                        .foregroundStyle(SettingsStyle.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle()
                    .fill(SettingsStyle.rowDivider)
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }
}

private struct SettingSwitch: View {
    @Binding var isOn: Bool
    let onLabel: String
    let offLabel: String
    var reduceMotion: Bool = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(isOn ? Color(red: 50 / 255, green: 215 / 255, blue: 75 / 255) : Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255))
                .frame(width: 42, height: 25)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                        .padding(2.5)
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? onLabel : offLabel)
    }
}

private struct LanguageSegmentedControl: View {
    @Binding var selection: SettingsLanguage

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsLanguage.allCases) { language in
                Button {
                    selection = language
                } label: {
                    Text(title(for: language))
                        .font(.system(size: 12, weight: selection == language ? .medium : .regular))
                        .foregroundStyle(selection == language ? SettingsStyle.primaryText : SettingsStyle.mutedText)
                        .frame(width: 72, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == language ? Color.white.opacity(0.10) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func title(for language: SettingsLanguage) -> String {
        switch language {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }
}

private struct SettingStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: 8) {
            stepperButton(symbol: "-", disabled: value <= range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }

            Text("\(value) \(unit)")
                .font(SettingsStyle.monoFont)
                .foregroundStyle(SettingsStyle.primaryText)
                .monospacedDigit()
                .frame(minWidth: 60)

            stepperButton(symbol: "+", disabled: value >= range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
    }

    private func stepperButton(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(disabled ? SettingsStyle.tertiaryText : SettingsStyle.mutedText)
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(disabled ? 0.03 : 0.06))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct OpacityControl: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $value, in: 0.55...0.92)
                .tint(EyePomoTheme.teal)
                .frame(width: 120)
            Text("\(Int(value * 100))%")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(SettingsStyle.secondaryText)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
    }
}

private struct SummaryCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundStyle(color.opacity(0.7))
                }
            }
            .lineLimit(1)

            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(SettingsStyle.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(SettingsStyle.groupBackground(reduceTransparency: reduceTransparency))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ChartPanel<Content: View>: View {
    let title: String
    let legend: [(String, Color)]
    let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(title: String, legend: [(String, Color)], @ViewBuilder content: () -> Content) {
        self.title = title
        self.legend = legend
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SettingsStyle.mutedText)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                HStack(spacing: 12) {
                    ForEach(legend, id: \.0) { item in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(item.1.opacity(0.85))
                                .frame(width: 8, height: 8)
                            Text(item.0)
                                .font(.system(size: 10.5))
                                .foregroundStyle(SettingsStyle.secondaryText)
                        }
                    }
                }
            }

            content
        }
        .padding(.top, 14)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(SettingsStyle.groupBackground(reduceTransparency: reduceTransparency))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MiniBar: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

private struct MiniBarChart: View {
    enum Kind {
        case integer
    }

    let bars: [MiniBar]
    let kind: Kind

    init(bars: [MiniBar], kind: Kind = .integer) {
        self.bars = bars
        self.kind = kind
    }

    private var maxValue: Double {
        max(bars.map(\.value).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            ForEach(bars) { bar in
                VStack(spacing: 7) {
                    Text(valueCaption(bar.value))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(bar.value > 0 ? bar.color : SettingsStyle.tertiaryText)
                        .monospacedDigit()

                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(bar.value > 0 ? bar.color.opacity(0.78) : SettingsStyle.rowDivider)
                                .frame(height: bar.value > 0
                                    ? max(6, proxy.size.height * (bar.value / maxValue))
                                    : 2
                                )
                        }
                    }
                    .frame(width: 28, height: 100)

                    Text(bar.label)
                        .font(.system(size: 10.5))
                        .foregroundStyle(SettingsStyle.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 132)
    }

    private func valueCaption(_ value: Double) -> String {
        switch kind {
        case .integer:
            return Int(value).description
        }
    }
}

/// 7-day trend chart: one bar per day, single dimension (Pomodoro counts).
/// All bars share the same scale so visual comparison is meaningful.
private struct TrendBarChart: View {
    let summaries: [DailySummary]
    let color: Color
    let reduceMotion: Bool

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        return formatter
    }

    private var maxValue: Double {
        let raw = summaries.map(\.focusSessionsCompleted).max() ?? 0
        return max(Double(raw), 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(summaries, id: \.dayKey) { summary in
                trendBar(for: summary)
            }
        }
        .frame(height: 132)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: summaries)
    }

    private func trendBar(for summary: DailySummary) -> some View {
        let count = summary.focusSessionsCompleted
        let fraction = Double(count) / maxValue
        let date = Self.isoFormatter.date(from: summary.dayKey) ?? Date()
        let isToday = summary.dayKey == summaries.last?.dayKey

        return VStack(spacing: 6) {
            Text(count > 0 ? "\(count)" : "—")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(count > 0 ? color : SettingsStyle.tertiaryText)
                .monospacedDigit()

            GeometryReader { proxy in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(count > 0 ? color.opacity(isToday ? 0.92 : 0.62) : SettingsStyle.rowDivider)
                        .frame(height: count > 0
                            ? max(4, proxy.size.height * fraction)
                            : 2
                        )
                }
            }
            .frame(height: 84)

            VStack(spacing: 1) {
                Text(weekdayFormatter.string(from: date))
                    .font(.system(size: 9.5, weight: isToday ? .medium : .regular))
                    .foregroundStyle(isToday ? SettingsStyle.primaryText : SettingsStyle.secondaryText)
                    .textCase(.uppercase)
                Text(Self.shortDayFormatter.string(from: date))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(SettingsStyle.tertiaryText)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DataActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .padding(.vertical, 4)
                .padding(.horizontal, 14)
                .background(color.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(color.opacity(0.20), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct StatusBar: View {
    let value: Double
    let accent: Color
    var reduceMotion: Bool = false

    private var clamped: Double {
        max(0, min(1, value))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                Capsule()
                    .fill(accent.opacity(0.85))
                    .frame(width: max(2, proxy.size.width * clamped))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: clamped)
            }
        }
        .frame(height: 4)
    }
}

private struct StatusDot: View {
    let accent: Color
    let isActive: Bool
    let reduceMotion: Bool

    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(accent)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .fill(accent.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isActive && !reduceMotion && pulse ? 1.4 : 1)
                    .opacity(isActive && !reduceMotion ? 1 : 0)
            )
            .onAppear {
                guard isActive, !reduceMotion else { return }
                pulse = true
            }
            .onChange(of: isActive) { newValue in
                guard newValue, !reduceMotion else {
                    pulse = false
                    return
                }
                pulse = true
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
    }
}

// MARK: - Data scope controls

enum DataScope: Hashable {
    case today
    case month
    case year
}

private struct DataScopeSegmentedControl: View {
    let selection: DataScope
    let language: SettingsLanguage
    let onChange: (DataScope) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach([DataScope.today, .month, .year], id: \.self) { scope in
                Button {
                    onChange(scope)
                } label: {
                    Text(title(for: scope))
                        .font(.system(size: 12, weight: selection == scope ? .medium : .regular))
                        .foregroundStyle(selection == scope ? SettingsStyle.primaryText : SettingsStyle.mutedText)
                        .frame(width: 56, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == scope ? Color.white.opacity(0.10) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func title(for scope: DataScope) -> String {
        let isEnglish = language == .english
        switch scope {
        case .today: return isEnglish ? "Today" : "今日"
        case .month: return isEnglish ? "Month" : "月"
        case .year: return isEnglish ? "Year" : "年"
        }
    }
}

private struct YearStepper: View {
    @Binding var year: Int
    let language: SettingsLanguage
    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        HStack(spacing: 4) {
            scopeButton(systemImage: "chevron.left") {
                if year > 2000 {
                    year -= 1
                }
            }
            Text("\(year)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(SettingsStyle.primaryText)
                .monospacedDigit()
                .frame(minWidth: 48)
            scopeButton(systemImage: "chevron.right") {
                if year < currentYear + 1 {
                    year += 1
                }
            }
        }
    }

    private func scopeButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SettingsStyle.mutedText)
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct MonthPicker: View {
    @Binding var year: Int
    @Binding var month: Int
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let currentMonth = Calendar.current.component(.month, from: Date())

    var body: some View {
        HStack(spacing: 4) {
            yearStepperCompact
            Text(String(format: "%04d", year))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(SettingsStyle.secondaryText)
                .monospacedDigit()
            monthSegmented
        }
    }

    private var yearStepperCompact: some View {
        HStack(spacing: 2) {
            Button {
                if year > 2000 { year -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SettingsStyle.mutedText)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            Button {
                if year < currentYear + 1 { year += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SettingsStyle.mutedText)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
        }
    }

    private var monthSegmented: some View {
        HStack(spacing: 2) {
            ForEach(1...12, id: \.self) { m in
                Button {
                    month = m
                } label: {
                    Text("\(m)")
                        .font(.system(size: 10, weight: month == m ? .semibold : .regular))
                        .foregroundStyle(month == m ? SettingsStyle.primaryText : SettingsStyle.mutedText)
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(month == m ? Color.white.opacity(0.10) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(m > currentMonth && year >= currentYear)
                .opacity(m > currentMonth && year >= currentYear ? 0.3 : 1)
            }
        }
    }
}
