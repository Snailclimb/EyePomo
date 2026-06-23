import EyePomoCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var selectedTab: SettingsTab = .eye

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
            HStack(spacing: 8) {
                SummaryCard(label: localized("今日番茄", "Today Pomodoros"), value: "\(coordinator.todaySummary.focusSessionsCompleted)", unit: localized("个", ""), color: EyePomoTheme.tomato)
                SummaryCard(label: localized("专注时长", "Focus Time"), value: focusHoursText, unit: localized("小时", "h"), color: SettingsStyle.primaryText)
                SummaryCard(label: localized("眼休次数", "Eye Breaks"), value: "\(coordinator.todaySummary.eyeBreaksCompleted)", unit: localized("次", ""), color: EyePomoTheme.teal)
            }

            ChartPanel(
                title: localized("今日概览", "Today"),
                legend: [(localized("番茄", "Pomodoros"), EyePomoTheme.tomato), (localized("眼休", "Eye breaks"), EyePomoTheme.teal)]
            ) {
                MiniBarChart(
                    bars: [
                        MiniBar(label: localized("番茄", "Pom."), value: max(1, Double(coordinator.todaySummary.focusSessionsCompleted)), color: EyePomoTheme.tomato),
                        MiniBar(label: localized("分钟", "Min"), value: max(1, Double(coordinator.todaySummary.focusMinutes)), color: SettingsStyle.primaryText),
                        MiniBar(label: localized("眼休", "Eyes"), value: max(1, Double(coordinator.todaySummary.eyeBreaksCompleted)), color: EyePomoTheme.teal),
                        MiniBar(label: localized("跳过", "Skip"), value: max(1, Double(coordinator.todaySummary.eyeBreaksSkipped)), color: SettingsStyle.warningRed)
                    ]
                )
            }

            SettingGroup(localized("界面", "Interface")) {
                SettingRow(localized("显示语言", "Display language"), sub: localized("切换设置窗口的显示语言", "Switch the language used in this settings window"), last: true) {
                    LanguageSegmentedControl(selection: languageBinding)
                }
            }

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
                SettingRow(localized("Markdown 摘要", "Markdown summaries"), sub: localized("每日摘要由本地事件日志生成", "Daily summaries are generated from local event logs")) {
                    DataActionButton(title: localized("本地", "Local"), color: EyePomoTheme.teal) {}
                        .disabled(true)
                }
                SettingRow(localized("恢复默认位置", "Restore default location"), sub: localized("切换回系统 Application Support 目录", "Switch back to the system Application Support folder"), last: true) {
                    DataActionButton(title: localized("恢复", "Reset"), color: SettingsStyle.warningRed) {
                        coordinator.resetDataDirectoryToDefault()
                    }
                }
            }

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
    }

    private var focusHoursText: String {
        let hours = Double(coordinator.todaySummary.focusMinutes) / 60
        if hours < 1 {
            return String(format: "%.1f", hours)
        }
        return String(format: "%.1f", hours)
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
            offLabel: localized("已关闭", "Off")
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

private enum SettingsStyle {
    static let outerBackground = Color(red: 26 / 255, green: 26 / 255, blue: 28 / 255)
    static let windowBackground = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let titleBarBackground = Color(red: 38 / 255, green: 38 / 255, blue: 40 / 255).opacity(0.98)
    static let toolbarBackground = Color(red: 32 / 255, green: 32 / 255, blue: 34 / 255).opacity(0.95)
    static let groupBackground = Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255).opacity(0.50)
    static let divider = Color.white.opacity(0.07)
    static let rowDivider = Color.white.opacity(0.06)
    static let primaryText = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    static let mutedText = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let secondaryText = Color(red: 99 / 255, green: 99 / 255, blue: 102 / 255)
    static let tertiaryText = Color(red: 72 / 255, green: 72 / 255, blue: 74 / 255)
    static let actionBlue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let warningRed = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)
    static let monoFont = Font.system(size: 13, weight: .regular, design: .monospaced)
}

private struct SettingGroup<Content: View>: View {
    let title: String?
    let content: Content

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
            .background(SettingsStyle.groupBackground)
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
                .animation(.easeInOut(duration: 0.18), value: isOn)
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
        .background(SettingsStyle.groupBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ChartPanel<Content: View>: View {
    let title: String
    let legend: [(String, Color)]
    let content: Content

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
        .background(SettingsStyle.groupBackground)
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
    let bars: [MiniBar]

    private var maxValue: Double {
        max(bars.map(\.value).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            ForEach(bars) { bar in
                VStack(spacing: 7) {
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(bar.color.opacity(0.78))
                                .frame(height: max(8, proxy.size.height * (bar.value / maxValue)))
                        }
                    }
                    .frame(width: 22, height: 112)

                    Text(bar.label)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(SettingsStyle.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 136)
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
