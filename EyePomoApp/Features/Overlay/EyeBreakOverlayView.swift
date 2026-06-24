import EyePomoCore
import SwiftUI

struct EyeBreakOverlayView: View {
    @ObservedObject var coordinator: AppCoordinator
    let request: OverlayRequest

    var body: some View {
        ZStack {
            overlayBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "eye")
                    .font(AppFont.font(46, weight: .medium))
                    .foregroundStyle(EyePomoTheme.teal)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text(localized("该休息一下眼睛了", "Time to rest your eyes"))
                        .font(AppFont.font(28, weight: .semibold))
                        .foregroundStyle(EyePomoTheme.primaryText)
                    Text(request.message)
                        .font(AppFont.font(16, weight: .medium))
                        .foregroundStyle(EyePomoTheme.secondaryText)
                    Text(localized("建议持续 \(request.durationSeconds) 秒", "Recommended for \(request.durationSeconds) seconds"))
                        .font(AppFont.font(13))
                        .foregroundStyle(EyePomoTheme.secondaryText)
                }

                HStack(spacing: 10) {
                    Button {
                        coordinator.send(.completeEyeBreak)
                    } label: {
                        Label(localized("完成", "Done"), systemImage: "checkmark")
                            .frame(width: 96)
                    }
                    .buttonStyle(PrimaryPanelButtonStyle(accent: EyePomoTheme.teal))
                    .focusable(false)

                    Button {
                        coordinator.send(.snoozeEyeBreak)
                    } label: {
                        Label(localized("稍后", "Snooze"), systemImage: "clock.arrow.circlepath")
                            .frame(width: 96)
                    }
                    .buttonStyle(SecondaryPanelButtonStyle())
                    .opacity(canSnooze ? 1 : 0.45)
                    .disabled(!canSnooze)
                    .focusable(false)

                    Button {
                        coordinator.send(.skipEyeBreak)
                    } label: {
                        Label(localized("跳过", "Skip"), systemImage: "forward")
                            .frame(width: 96)
                    }
                    .buttonStyle(SecondaryPanelButtonStyle())
                    .focusable(false)
                }
            }
            .padding(.vertical, 34)
            .padding(.horizontal, 38)
            .background(EyePomoTheme.cardBackground.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: AppDensityProfile.metrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDensityProfile.metrics.cornerRadius, style: .continuous)
                    .stroke(EyePomoTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 28, x: 0, y: 16)
        }
        .id(coordinator.appSettings)
        .preferredColorScheme(Appearance.resolvedColorScheme(coordinator.appSettings.appearance))
    }

    private var overlayBackground: Color {
        Color.dynamic(
            light: Color(red: 248 / 255, green: 251 / 255, blue: 250 / 255).opacity(0.82),
            dark: Color(red: 8 / 255, green: 13 / 255, blue: 16 / 255).opacity(0.78)
        )
    }

    private var canSnooze: Bool {
        coordinator.state.eyeBreak.snoozeCount < max(0, coordinator.state.preferences.maxSnoozesPerEyeBreak)
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        coordinator.appSettings.language == .english ? english : chinese
    }
}
