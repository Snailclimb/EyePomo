import EyePomoCore
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var coordinator: AppCoordinator

    private var snapshot: DisplaySnapshot {
        coordinator.state.displaySnapshot(at: coordinator.currentInstant)
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            timerCard
            actionGrid
            TodayStatsView(summary: coordinator.todaySummary)
            footer
        }
        .padding(16)
        .frame(width: 320)
        .background(EyePomoTheme.panelBackground)
        .foregroundStyle(EyePomoTheme.primaryText)
        .id(coordinator.appSettings)
        .preferredColorScheme(Appearance.resolvedColorScheme(coordinator.appSettings.appearance))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("EyePomo")
                    .font(AppFont.font(15, weight: .semibold))
                Text(snapshot.stateLabel)
                    .font(AppFont.font(12, weight: .medium))
                    .foregroundStyle(EyePomoTheme.secondaryText)
            }
            Spacer()
            Circle()
                .fill(accentColor)
                .frame(width: 9, height: 9)
        }
    }

    private var timerCard: some View {
        VStack(spacing: 10) {
            Text(snapshot.countdown)
                .font(AppFont.font(48, weight: .semibold, design: .monospaced))
                .foregroundStyle(EyePomoTheme.primaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ProgressView(value: snapshot.progress)
                .tint(accentColor)
                .controlSize(.small)

            Button {
                coordinator.send(snapshot.primaryAction)
            } label: {
                Label(snapshot.primaryTitle, systemImage: primaryIconName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryPanelButtonStyle(accent: accentColor))
            .focusable(false)
        }
        .padding(14)
        .background(EyePomoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(EyePomoTheme.border, lineWidth: 1)
        )
    }

    private var actionGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                secondaryButton(localized("立即眼休", "Eye break now"), icon: "eye", action: .requestEyeBreakNow)
                snoozeOrPauseButton
            }
            HStack(spacing: 8) {
                secondaryButton(localized("下一阶段", "Next phase"), icon: "forward.end", action: .skipPomodoroPhase)
                secondaryButton(localized("重置番茄", "Reset Pomodoro"), icon: "arrow.counterclockwise", action: .resetPomodoro)
            }
            HStack(spacing: 8) {
                presentationModeButton
                muteTodayButton
            }
        }
    }

    private var footer: some View {
        Button {
            coordinator.showSettings()
        } label: {
            Label(localized("设置", "Settings"), systemImage: "gearshape")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryPanelButtonStyle())
        .focusable(false)
    }

    @ViewBuilder
    private var snoozeOrPauseButton: some View {
        if isEyeBreakActive {
            secondaryButton(
                canSnoozeEyeBreak ? localized("稍后提醒", "Snooze") : localized("稍后已达上限", "Snooze limit"),
                icon: "clock.arrow.circlepath",
                action: .snoozeEyeBreak,
                disabled: !canSnoozeEyeBreak
            )
        } else {
            secondaryButton(localized("暂停 1 小时", "Pause 1 hour"), icon: "pause.circle", action: .pauseReminders(seconds: 3_600))
        }
    }

    private var muteTodayButton: some View {
        secondaryButton(
            isMutedForToday ? localized("今日已静音", "Muted today") : localized("今日静音", "Mute today"),
            icon: isMutedForToday ? "bell.slash.fill" : "bell.slash",
            action: .muteRemindersForToday,
            disabled: isMutedForToday
        )
    }

    private func secondaryButton(_ title: String, icon: String, action: UserAction, disabled: Bool = false) -> some View {
        Button {
            coordinator.send(action)
        } label: {
            Label(title, systemImage: icon)
                .font(AppFont.font(12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryPanelButtonStyle())
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
        .focusable(false)
    }

    private var presentationModeButton: some View {
        let isActive = coordinator.state.suppression.isPresentationModeActive(at: Date())
        return Button {
            if isActive {
                coordinator.send(.endPresentationMode)
            } else {
                coordinator.send(.startPresentationMode(seconds: coordinator.state.preferences.presentationModeDurationSeconds))
            }
        } label: {
            Label(
                isActive ? localized("结束会议", "End meeting") : localized("会议模式", "Meeting mode"),
                systemImage: isActive ? "person.crop.circle.badge.checkmark" : "person.2"
            )
            .font(AppFont.font(12, weight: .medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryPanelButtonStyle())
        .focusable(false)
    }

    private var accentColor: Color {
        switch snapshot.accent {
        case .teal:
            return EyePomoTheme.teal
        case .tomato:
            return EyePomoTheme.tomato
        case .neutral:
            return EyePomoTheme.secondaryText
        }
    }

    private var primaryIconName: String {
        switch snapshot.primaryAction {
        case .startPomodoro:
            return "play.fill"
        case .pausePomodoro:
            return "pause.fill"
        case .resumePomodoro:
            return "play.fill"
        case .endPomodoroBreak:
            return "checkmark"
        default:
            return "bolt.fill"
        }
    }

    private var isEyeBreakActive: Bool {
        coordinator.state.eyeBreak.phase == .active || coordinator.state.presentation.activeOverlay == .eyeBreak
    }

    private var canSnoozeEyeBreak: Bool {
        coordinator.state.eyeBreak.snoozeCount < max(0, coordinator.state.preferences.maxSnoozesPerEyeBreak)
    }

    private var isMutedForToday: Bool {
        coordinator.state.suppression.mutedForDate == WorkHoursPolicy.dayKey(Date(), calendar: Calendar.current)
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        coordinator.appSettings.language == .english ? english : chinese
    }
}
