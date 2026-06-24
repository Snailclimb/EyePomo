import Foundation

public enum MarkdownJournalRenderer {
    public static func renderMonthly(
        monthKey: String,
        summaries: [DailySummary],
        preferences: AppPreferences,
        timeZoneIdentifier: String,
        recoveredCorruptFinalLine: Bool = false
    ) -> String {
        let sortedSummaries = summaries.sorted { $0.dayKey < $1.dayKey }
        let totalFocusSessions = sortedSummaries.reduce(0) { $0 + $1.focusSessionsCompleted }
        let totalFocusMinutes = sortedSummaries.reduce(0) { $0 + $1.focusMinutes }
        let totalEyeBreaksCompleted = sortedSummaries.reduce(0) { $0 + $1.eyeBreaksCompleted }
        let totalEyeBreaksSkipped = sortedSummaries.reduce(0) { $0 + $1.eyeBreaksSkipped }
        let totalInferredRests = sortedSummaries.reduce(0) { $0 + $1.inferredRests }
        let longestUsage = sortedSummaries.map(\.longestContinuousUsageMinutes).max() ?? 0

        var lines: [String] = []
        lines.append("---")
        lines.append("month: \(monthKey)")
        lines.append("time_zone: \(timeZoneIdentifier)")
        lines.append("focus_sessions_completed: \(totalFocusSessions)")
        lines.append("focus_minutes: \(totalFocusMinutes)")
        lines.append("eye_breaks_completed: \(totalEyeBreaksCompleted)")
        lines.append("eye_breaks_skipped: \(totalEyeBreaksSkipped)")
        lines.append("inferred_rests: \(totalInferredRests)")
        lines.append("longest_continuous_usage_minutes: \(longestUsage)")
        lines.append("settings_snapshot:")
        lines.append("  eye_break_interval_minutes: \(preferences.eyeBreakIntervalSeconds / 60)")
        lines.append("  eye_break_duration_seconds: \(preferences.eyeBreakDurationSeconds)")
        lines.append("  focus_minutes: \(preferences.focusDurationSeconds / 60)")
        lines.append("  short_break_minutes: \(preferences.shortBreakDurationSeconds / 60)")
        lines.append("  long_break_minutes: \(preferences.longBreakDurationSeconds / 60)")
        lines.append("---")
        lines.append("")
        lines.append("# \(monthKey) 专注与护眼记录")
        lines.append("")
        lines.append("本月完成 \(totalFocusSessions) 个番茄钟，共专注 \(totalFocusMinutes) 分钟。")
        lines.append("")
        lines.append("眼休完成 \(totalEyeBreaksCompleted) 次，跳过 \(totalEyeBreaksSkipped) 次，推测休息 \(totalInferredRests) 次。")
        lines.append("")
        lines.append("最长连续使用时段约 \(longestUsage) 分钟。")

        if recoveredCorruptFinalLine {
            lines.append("")
            lines.append("> 注意：事件日志最后一行可能未完整写入，已使用此前有效事件生成本摘要。")
        }

        lines.append("")
        lines.append("## 每日统计")
        lines.append("")
        lines.append("| 日期 | 番茄数 | 专注分钟 | 眼休完成 | 眼休跳过 | 推测休息 | 最长连续使用分钟 |")
        lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
        for summary in sortedSummaries {
            lines.append("| \(summary.dayKey) | \(summary.focusSessionsCompleted) | \(summary.focusMinutes) | \(summary.eyeBreaksCompleted) | \(summary.eyeBreaksSkipped) | \(summary.inferredRests) | \(summary.longestContinuousUsageMinutes) |")
        }

        lines.append("")
        lines.append("## 可供本地 AI 分析的问题")
        lines.append("")
        lines.append("- 本月是否存在固定疲劳时段？")
        lines.append("- 哪些日期眼休跳过率明显升高？")
        lines.append("- 番茄钟时长是否需要调整？")
        lines.append("")
        return lines.joined(separator: "\n")
    }

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
