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
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("EyePomo")
                    .font(.system(size: 15, weight: .semibold))
                Text(snapshot.stateLabel)
                    .font(.system(size: 12, weight: .medium))
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
                .font(.system(size: 48, weight: .semibold, design: .monospaced))
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
                secondaryButton("跳到下一阶段", icon: "forward.end", action: .skipPomodoroPhase)
                secondaryButton("重置番茄", icon: "arrow.counterclockwise", action: .resetPomodoro)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                coordinator.showSettings()
            } label: {
                Label(localized("设置", "Settings"), systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryPanelButtonStyle())

            Button {
                coordinator.openLogsDirectory()
            } label: {
                Label(localized("日志", "Logs"), systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryPanelButtonStyle())
        }
    }

    private func secondaryButton(_ title: String, icon: String, action: UserAction) -> some View {
        Button {
            coordinator.send(action)
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryPanelButtonStyle())
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
