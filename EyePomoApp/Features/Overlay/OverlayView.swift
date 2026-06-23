import EyePomoCore
import SwiftUI

struct OverlayView: View {
    @ObservedObject var coordinator: AppCoordinator
    let request: OverlayRequest
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
            OverlayTintSurface(
                tint: coordinator.state.preferences.overlayTint,
                opacity: coordinator.state.preferences.overlayOpacity,
                reduceTransparency: reduceTransparency
            )

            VStack(spacing: 18) {
                Image(systemName: iconName)
                    .font(AppFont.font(34, weight: .semibold))
                    .foregroundStyle(accent)

                VStack(spacing: 6) {
                    Text(title)
                        .font(AppFont.font(22, weight: .semibold))
                    Text(message)
                        .font(AppFont.font(13, weight: .medium))
                        .foregroundStyle(EyePomoTheme.secondaryText)
                }

                Text(AppState.format(seconds: remainingSeconds))
                    .font(AppFont.font(64, weight: .semibold, design: .monospaced))
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                controls
                    .frame(width: 320)
            }
            .padding(26)
            .foregroundStyle(EyePomoTheme.primaryText)
            .background(EyePomoTheme.panelBackground.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: AppDensityProfile.metrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDensityProfile.metrics.cornerRadius, style: .continuous)
                    .stroke(EyePomoTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.32), radius: 28, x: 0, y: 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(Appearance.resolvedColorScheme(coordinator.appSettings.appearance))
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

private struct OverlayTintSurface: View {
    let tint: OverlayTint
    let opacity: Double
    let reduceTransparency: Bool

    private var clampedOpacity: Double {
        max(0.35, min(0.96, opacity))
    }

    private var effectiveOpacity: Double {
        reduceTransparency ? max(0.90, clampedOpacity) : clampedOpacity
    }

    var body: some View {
        ZStack {
            baseColor
                .opacity(effectiveOpacity)

            if tint == .warm && !reduceTransparency {
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.56, blue: 0.25).opacity(clampedOpacity * 0.34),
                        Color(red: 0.43, green: 0.18, blue: 0.08).opacity(clampedOpacity * 0.18),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }

    private var baseColor: Color {
        switch tint {
        case .warm:
            return Color(red: 0.13, green: 0.08, blue: 0.04)
        case .dark:
            return .black
        }
    }
}
