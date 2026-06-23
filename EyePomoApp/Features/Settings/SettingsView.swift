import EyePomoCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                eyeBreakSection
                pomodoroSection
                timeSection
                dataSection
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EyePomoTheme.settingsBackground)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EyePomo 设置")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(EyePomoTheme.primaryText)
            Text("护眼提醒、番茄节奏、工作时段与本地数据")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(EyePomoTheme.secondaryText)
        }
    }

    private var eyeBreakSection: some View {
        SettingsSection(title: "护眼设置", icon: "eye") {
            StepperRow(
                title: "提醒间隔",
                value: minutesBinding(\.eyeBreakIntervalSeconds),
                range: 5...90,
                unit: "分钟"
            )
            StepperRow(
                title: "休息时长",
                value: secondsBinding(\.eyeBreakDurationSeconds),
                range: 10...120,
                unit: "秒"
            )
            StepperRow(
                title: "稍后提醒",
                value: minutesBinding(\.snoozeSeconds),
                range: 1...30,
                unit: "分钟"
            )
        }
    }

    private var pomodoroSection: some View {
        SettingsSection(title: "番茄钟设置", icon: "timer") {
            StepperRow(title: "专注时长", value: minutesBinding(\.focusDurationSeconds), range: 5...90, unit: "分钟")
            StepperRow(title: "短休时长", value: minutesBinding(\.shortBreakDurationSeconds), range: 1...30, unit: "分钟")
            StepperRow(title: "长休时长", value: minutesBinding(\.longBreakDurationSeconds), range: 5...45, unit: "分钟")
            StepperRow(title: "长休周期", value: intBinding(\.longBreakEvery), range: 2...8, unit: "个番茄")
        }
    }

    private var timeSection: some View {
        SettingsSection(title: "时间与提醒", icon: "bell.badge") {
            Toggle("启用工作时段限制", isOn: boolBinding(\.workHoursEnabled))
                .toggleStyle(.switch)
            StepperRow(title: "开始时间", value: hourBinding(\.workStartMinuteOfDay), range: 0...23, unit: "点")
            StepperRow(title: "结束时间", value: hourBinding(\.workEndMinuteOfDay), range: 1...24, unit: "点")
            StepperRow(title: "空闲推测休息", value: minutesBinding(\.idleThresholdSeconds), range: 1...20, unit: "分钟")
        }
    }

    private var dataSection: some View {
        SettingsSection(title: "数据与日志", icon: "doc.text") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本地日志目录")
                        .font(.system(size: 13, weight: .medium))
                    Text(AppPaths.logsDirectory.path)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(EyePomoTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    coordinator.openLogsDirectory()
                } label: {
                    Label("打开", systemImage: "folder")
                }
                .buttonStyle(SecondaryPanelButtonStyle())
            }
        }
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
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(EyePomoTheme.primaryText)
            VStack(spacing: 10) {
                content
            }
        }
        .padding(14)
        .background(EyePomoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(EyePomoTheme.border, lineWidth: 1)
        )
    }
}

private struct StepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(value) \(unit)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(EyePomoTheme.secondaryText)
            }
        }
    }
}
