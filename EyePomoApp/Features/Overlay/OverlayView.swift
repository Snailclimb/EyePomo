import EyePomoCore
import SwiftUI

struct OverlayView: View {
    @ObservedObject var coordinator: AppCoordinator
    let request: OverlayRequest
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var remainingSeconds: Int {
        switch request.kind {
        case .eyeBreak:
            return coordinator.state.eyeBreak.remainingSeconds(at: coordinator.currentInstant)
        case .shortBreak, .longBreak:
            return coordinator.state.pomodoro.remainingSeconds(at: coordinator.currentInstant)
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(coordinator.state.preferences.overlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(accent)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(EyePomoTheme.secondaryText)
                }

                Text(AppState.format(seconds: remainingSeconds))
                    .font(.system(size: 64, weight: .semibold, design: .monospaced))
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                controls
                    .frame(width: 320)
            }
            .padding(26)
            .foregroundStyle(EyePomoTheme.primaryText)
            .background(EyePomoTheme.panelBackground.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(EyePomoTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.32), radius: 28, x: 0, y: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                complete()
            } label: {
                Label("完成", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryPanelButtonStyle(accent: accent))

            Button {
                snooze()
            } label: {
                Label("稍后", systemImage: "clock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryPanelButtonStyle())

            Button {
                skip()
            } label: {
                Label("跳过", systemImage: "forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryPanelButtonStyle())
        }
    }

    private func complete() {
        switch request.kind {
        case .eyeBreak:
            coordinator.send(.completeEyeBreak)
        case .shortBreak, .longBreak:
            coordinator.send(.endPomodoroBreak)
        }
    }

    private func snooze() {
        switch request.kind {
        case .eyeBreak:
            coordinator.send(.snoozeEyeBreak)
        case .shortBreak, .longBreak:
            coordinator.send(.pauseReminders(seconds: coordinator.state.preferences.snoozeSeconds))
        }
    }

    private func skip() {
        switch request.kind {
        case .eyeBreak:
            coordinator.send(.skipEyeBreak)
        case .shortBreak, .longBreak:
            coordinator.send(.skipPomodoroPhase)
        }
    }

    private var title: String {
        switch request.kind {
        case .eyeBreak:
            return "20 秒护眼休息"
        case .shortBreak:
            return "短休一下"
        case .longBreak:
            return "长休一下"
        }
    }

    private var message: String {
        switch request.kind {
        case .eyeBreak:
            return "看向 6 米外，让眼睛重新对焦"
        case .shortBreak, .longBreak:
            return "离开屏幕，喝水或活动一下"
        }
    }

    private var iconName: String {
        switch request.kind {
        case .eyeBreak:
            return "eye"
        case .shortBreak, .longBreak:
            return "cup.and.saucer"
        }
    }

    private var accent: Color {
        switch request.kind {
        case .eyeBreak, .shortBreak, .longBreak:
            return EyePomoTheme.teal
        }
    }
}
