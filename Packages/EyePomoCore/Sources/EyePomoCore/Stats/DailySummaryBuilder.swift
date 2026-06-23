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
    /// Builds the summary for a single day. Internally goes through `buildAll`
    /// so the per-day aggregation logic lives in exactly one place.
    public static func build(
        events: [EventEnvelope],
        day: Date,
        calendar: Calendar
    ) -> DailySummary {
        let key = WorkHoursPolicy.dayKey(day, calendar: calendar)
        let byDay = buildAll(events: events, calendar: calendar)
        return byDay[key] ?? DailySummary(dayKey: key)
    }

    /// Scans the event stream once and groups it by `dayKey`, returning every
    /// day that has at least one event. This is the foundation for multi-day
    /// views (trend, year, month, heatmap) and avoids the O(days × events)
    /// cost of calling `build` once per day.
    public static func buildAll(
        events: [EventEnvelope],
        calendar: Calendar
    ) -> [String: DailySummary] {
        let sortedEvents = events.sorted { $0.occurredAt < $1.occurredAt }

        var buckets: [String: DayBucket] = [:]

        for event in sortedEvents {
            let key = WorkHoursPolicy.dayKey(event.occurredAt, calendar: calendar)
            var bucket = buckets[key] ?? DayBucket(dayKey: key)
            var currentUsageStart = bucket.openUsageStart

            switch event.kind {
            case .pomodoroFocusCompleted(let payload):
                bucket.summary.focusSessionsCompleted += 1
                bucket.summary.focusMinutes += payload.durationSeconds / 60
            case .eyeBreakCompleted:
                bucket.summary.eyeBreaksCompleted += 1
                closeUsageSegment(start: &currentUsageStart, end: event.occurredAt, summary: &bucket.summary)
            case .eyeBreakSkipped:
                bucket.summary.eyeBreaksSkipped += 1
            case .inferredRest:
                bucket.summary.inferredRests += 1
                closeUsageSegment(start: &currentUsageStart, end: event.occurredAt, summary: &bucket.summary)
            case .sleepStarted, .screenLocked, .pomodoroBreakStarted:
                closeUsageSegment(start: &currentUsageStart, end: event.occurredAt, summary: &bucket.summary)
            case .wakeDetected, .screenUnlocked, .pomodoroStarted, .eyeBreakDue:
                if currentUsageStart == nil {
                    currentUsageStart = event.occurredAt
                }
            default:
                break
            }

            if let start = currentUsageStart {
                let minutes = max(0, Int(event.occurredAt.timeIntervalSince(start) / 60))
                bucket.summary.longestContinuousUsageMinutes = max(bucket.summary.longestContinuousUsageMinutes, minutes)
            }

            bucket.openUsageStart = currentUsageStart
            buckets[key] = bucket
        }

        var result: [String: DailySummary] = [:]
        for (key, bucket) in buckets {
            result[key] = bucket.summary
        }
        return result
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

/// Mutable per-day accumulator used while scanning events in `buildAll`.
/// `openUsageStart` carries the start of a not-yet-closed usage segment
/// across consecutive events so `longestContinuousUsageMinutes` matches the
/// single-day `build` behavior.
private struct DayBucket {
    var summary: DailySummary
    var openUsageStart: Date?

    init(dayKey: String) {
        self.summary = DailySummary(dayKey: dayKey)
        self.openUsageStart = nil
    }
}
