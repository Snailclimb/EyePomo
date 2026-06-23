import Foundation

public struct DailySummary: Codable, Sendable, Equatable {
    public var dayKey: String
    public var focusSessionsCompleted: Int
    public var focusMinutes: Int
    public var eyeBreaksCompleted: Int
    public var eyeBreaksSkipped: Int
    public var inferredRests: Int
    public var longestContinuousUsageMinutes: Int

    public init(
        dayKey: String,
        focusSessionsCompleted: Int = 0,
        focusMinutes: Int = 0,
        eyeBreaksCompleted: Int = 0,
        eyeBreaksSkipped: Int = 0,
        inferredRests: Int = 0,
        longestContinuousUsageMinutes: Int = 0
    ) {
        self.dayKey = dayKey
        self.focusSessionsCompleted = focusSessionsCompleted
        self.focusMinutes = focusMinutes
        self.eyeBreaksCompleted = eyeBreaksCompleted
        self.eyeBreaksSkipped = eyeBreaksSkipped
        self.inferredRests = inferredRests
        self.longestContinuousUsageMinutes = longestContinuousUsageMinutes
    }
}

public enum DailySummaryBuilder {
    public static func build(
        events: [EventEnvelope],
        day: Date,
        calendar: Calendar
    ) -> DailySummary {
        let key = WorkHoursPolicy.dayKey(day, calendar: calendar)
        let dayEvents = events
            .filter { WorkHoursPolicy.dayKey($0.occurredAt, calendar: calendar) == key }
            .sorted { $0.occurredAt < $1.occurredAt }

        var summary = DailySummary(dayKey: key)
        var currentUsageStart: Date?

        for event in dayEvents {
            switch event.kind {
            case .pomodoroFocusCompleted(let payload):
                summary.focusSessionsCompleted += 1
                summary.focusMinutes += payload.durationSeconds / 60
            case .eyeBreakCompleted:
                summary.eyeBreaksCompleted += 1
                closeUsageSegment(start: &currentUsageStart, end: event.occurredAt, summary: &summary)
            case .eyeBreakSkipped:
                summary.eyeBreaksSkipped += 1
            case .inferredRest:
                summary.inferredRests += 1
                closeUsageSegment(start: &currentUsageStart, end: event.occurredAt, summary: &summary)
            case .sleepStarted, .screenLocked, .pomodoroBreakStarted:
                closeUsageSegment(start: &currentUsageStart, end: event.occurredAt, summary: &summary)
            case .wakeDetected, .screenUnlocked, .pomodoroStarted, .eyeBreakDue:
                if currentUsageStart == nil {
                    currentUsageStart = event.occurredAt
                }
            default:
                break
            }
        }

        if let start = currentUsageStart {
            let end = dayEvents.last?.occurredAt ?? day
            let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
            summary.longestContinuousUsageMinutes = max(summary.longestContinuousUsageMinutes, minutes)
        }

        return summary
    }

    private static func closeUsageSegment(start: inout Date?, end: Date, summary: inout DailySummary) {
        guard let value = start else {
            return
        }
        let minutes = max(0, Int(end.timeIntervalSince(value) / 60))
        summary.longestContinuousUsageMinutes = max(summary.longestContinuousUsageMinutes, minutes)
        start = nil
    }
}
