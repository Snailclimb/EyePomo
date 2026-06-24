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
                secondaryButton("立即眼休", icon: "eye", action: .requestEyeBreakNow)
                secondaryButton("稍后提醒", icon: "clock.arrow.circlepath", action: .snoozeEyeBreak)
            }
            HStack(spacing: 8) {
                secondaryButton("下一阶段", icon: "forward.end", action: .skipPomodoroPhase)
                secondaryButton("重置番茄", icon: "arrow.counterclockwise", action: .resetPomodoro)
            }
            HStack(spacing: 8) {
                presentationModeButton
                secondaryButton(localized("今日静音", "Mute today"), icon: "bell.slash", action: .muteRemindersForToday)
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

    private func secondaryButton(_ title: String, icon: String, action: UserAction) -> some View {
        Button {
            coordinator.send(action)
        } label: {
            Label(title, systemImage: icon)
                .font(AppFont.font(12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryPanelButtonStyle())
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

    private func localized(_ chinese: String, _ english: String) -> String {
        coordinator.appSettings.language == .english ? english : chinese
    }
}
