import Foundation

public enum MarkdownJournalRenderer {
    public static func render(
        summary: DailySummary,
        preferences: AppPreferences,
        timeZoneIdentifier: String,
        recoveredCorruptFinalLine: Bool = false
    ) -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("date: \(summary.dayKey)")
        lines.append("time_zone: \(timeZoneIdentifier)")
        lines.append("focus_sessions_completed: \(summary.focusSessionsCompleted)")
        lines.append("focus_minutes: \(summary.focusMinutes)")
        lines.append("eye_breaks_completed: \(summary.eyeBreaksCompleted)")
        lines.append("eye_breaks_skipped: \(summary.eyeBreaksSkipped)")
        lines.append("inferred_rests: \(summary.inferredRests)")
        lines.append("longest_continuous_usage_minutes: \(summary.longestContinuousUsageMinutes)")
        lines.append("settings_snapshot:")
        lines.append("  eye_break_interval_minutes: \(preferences.eyeBreakIntervalSeconds / 60)")
        lines.append("  eye_break_duration_seconds: \(preferences.eyeBreakDurationSeconds)")
        lines.append("  focus_minutes: \(preferences.focusDurationSeconds / 60)")
        lines.append("  short_break_minutes: \(preferences.shortBreakDurationSeconds / 60)")
        lines.append("  long_break_minutes: \(preferences.longBreakDurationSeconds / 60)")
        lines.append("---")
        lines.append("")
        lines.append("# \(summary.dayKey) 专注与护眼记录")
        lines.append("")
        lines.append("今天完成 \(summary.focusSessionsCompleted) 个番茄钟，共专注 \(summary.focusMinutes) 分钟。")
        lines.append("")
        lines.append("眼休完成 \(summary.eyeBreaksCompleted) 次，跳过 \(summary.eyeBreaksSkipped) 次，推测休息 \(summary.inferredRests) 次。")
        lines.append("")
        lines.append("最长连续使用时段约 \(summary.longestContinuousUsageMinutes) 分钟。")

        if recoveredCorruptFinalLine {
            lines.append("")
            lines.append("> 注意：事件日志最后一行可能未完整写入，已使用此前有效事件生成本摘要。")
        }

        lines.append("")
        lines.append("## 可供本地 AI 分析的问题")
        lines.append("")
        lines.append("- 最近 7 天是否存在固定疲劳时段？")
        lines.append("- 眼休跳过率是否升高？")
        lines.append("- 番茄钟时长是否需要调整？")
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
