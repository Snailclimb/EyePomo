import EyePomoCore
import SwiftUI

struct TodayStatsView: View {
    let summary: DailySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日统计")
                .font(.system(size: 13, weight: .semibold))
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(EyePomoTheme.border, lineWidth: 1)
        )
    }

    private func stat(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(EyePomoTheme.primaryText)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(EyePomoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
