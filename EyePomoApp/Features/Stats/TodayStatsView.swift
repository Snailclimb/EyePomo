import EyePomoCore
import SwiftUI

struct TodayStatsView: View {
    let summary: DailySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日统计")
                .font(AppFont.font(13, weight: .semibold))
                .foregroundStyle(EyePomoTheme.primaryText)

            HStack(spacing: 8) {
                stat("番茄", value: "\(summary.focusSessionsCompleted)")
                stat("分钟", value: "\(summary.focusMinutes)")
                stat("眼休", value: "\(summary.eyeBreaksCompleted)")
                stat("跳过", value: "\(summary.eyeBreaksSkipped)")
            }
        }
        .padding(12)
        .background(EyePomoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppDensityProfile.metrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDensityProfile.metrics.cornerRadius, style: .continuous)
                .stroke(EyePomoTheme.border, lineWidth: 1)
        )
    }

    private func stat(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.font(18, weight: .semibold, design: .rounded))
                .foregroundStyle(EyePomoTheme.primaryText)
            Text(title)
                .font(AppFont.font(11, weight: .medium))
                .foregroundStyle(EyePomoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
