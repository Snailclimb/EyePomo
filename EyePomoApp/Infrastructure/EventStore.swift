import EyePomoCore
import Foundation

actor EventStore {
    func append(_ event: EventEnvelope, paths: AppPaths) throws {
        try paths.ensureBaseDirectories()
        let url = logURL(for: event.occurredAt, paths: paths)
        let line = try EventLogCodec.encodeLine(event) + "\n"
        let data = Data(line.utf8)

        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            handle.write(data)
            try handle.close()
        } else {
            try data.write(to: url, options: .atomic)
        }
    }

    func loadAllEvents(paths: AppPaths) -> EventLogDecodeResult {
        try? paths.ensureBaseDirectories()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: paths.logsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        var events: [EventEnvelope] = []
        var recoveredCorruptFinalLine = false
        var failedLineCount = 0

        for url in urls where url.pathExtension == "jsonl" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let result = EventLogCodec.decodeJSONLLines(text)
            events.append(contentsOf: result.events)
            recoveredCorruptFinalLine = recoveredCorruptFinalLine || result.recoveredCorruptFinalLine
            failedLineCount += result.failedLineCount
        }

        return EventLogDecodeResult(
            events: events.sorted { $0.occurredAt < $1.occurredAt },
            recoveredCorruptFinalLine: recoveredCorruptFinalLine,
            failedLineCount: failedLineCount
        )
    }

    func regenerateJournal(for day: Date, preferences: AppPreferences, calendar: Calendar, paths: AppPaths) throws -> DailySummary {
        let decoded = loadAllEvents(paths: paths)
        let byDay = DailySummaryBuilder.buildAll(events: decoded.events, calendar: calendar)
        let dayKey = WorkHoursPolicy.dayKey(day, calendar: calendar)
        let summary = byDay[dayKey] ?? DailySummary(dayKey: dayKey)
        let monthKey = Self.monthKey(for: day, calendar: calendar)
        let markdown = MarkdownJournalRenderer.renderMonthly(
            monthKey: monthKey,
            summaries: Self.monthSummaries(upTo: day, from: byDay, calendar: calendar),
            preferences: preferences,
            timeZoneIdentifier: calendar.timeZone.identifier,
            recoveredCorruptFinalLine: decoded.recoveredCorruptFinalLine
        )

        try paths.ensureBaseDirectories()
        let url = paths.journalsDirectory.appendingPathComponent("\(monthKey).md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        try writeSummaryCaches(upTo: day, byDay: byDay, calendar: calendar, paths: paths)
        return summary
    }

    /// Builds daily summaries for the last `dayCount` days ending at `endDate` (inclusive),
    /// without touching journal files. Reused for trend charts in the UI.
    func loadDailySummaries(endingAt endDate: Date, dayCount: Int, calendar: Calendar, paths: AppPaths) -> [DailySummary] {
        let decoded = loadAllEvents(paths: paths)
        let byDay = DailySummaryBuilder.buildAll(events: decoded.events, calendar: calendar)

        return (0..<max(1, dayCount)).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDate) else {
                return DailySummary(dayKey: WorkHoursPolicy.dayKey(endDate, calendar: calendar))
            }
            let dayStart = calendar.startOfDay(for: day)
            let key = WorkHoursPolicy.dayKey(dayStart, calendar: calendar)
            return byDay[key] ?? DailySummary(dayKey: key)
        }
    }

    /// Returns one summary per day in the given year, keyed by `dayKey`.
    /// Days with no events are absent from the dictionary; the UI renders
    /// empty cells for them. Goes through `buildAll` so a full year is a
    /// single scan instead of 365 separate filters.
    func loadSummaries(forYear year: Int, calendar: Calendar, paths: AppPaths) -> [String: DailySummary] {
        let yearStart = Self.utcCalendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let nextYearStart = Self.utcCalendar.date(byAdding: .year, value: 1, to: yearStart)!

        let decoded = loadAllEvents(paths: paths)
        let byDay = DailySummaryBuilder.buildAll(events: decoded.events, calendar: calendar)
        return byDay.filter { entry in
            guard let date = Self.dayKeyFormatter.date(from: entry.key) else {
                return false
            }
            return date >= yearStart && date < nextYearStart
        }
    }

    /// Returns one summary per day in the given month (1...12) of `year`.
    func loadSummaries(forMonth month: Int, ofYear year: Int, calendar: Calendar, paths: AppPaths) -> [String: DailySummary] {
        let monthStart = Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let nextMonthStart = Self.utcCalendar.date(byAdding: .month, value: 1, to: monthStart)!

        let decoded = loadAllEvents(paths: paths)
        let byDay = DailySummaryBuilder.buildAll(events: decoded.events, calendar: calendar)
        return byDay.filter { entry in
            guard let date = Self.dayKeyFormatter.date(from: entry.key) else {
                return false
            }
            return date >= monthStart && date < nextMonthStart
        }
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func monthKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        return String(format: "%04d-%02d", year, month)
    }

    private static func monthSummaries(
        upTo date: Date,
        from byDay: [String: DailySummary],
        calendar: Calendar
    ) -> [DailySummary] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            let dayKey = WorkHoursPolicy.dayKey(date, calendar: calendar)
            return [byDay[dayKey] ?? DailySummary(dayKey: dayKey)]
        }

        let lastDay = calendar.startOfDay(for: date)
        var cursor = calendar.startOfDay(for: monthInterval.start)
        var summaries: [DailySummary] = []

        while cursor <= lastDay {
            let key = WorkHoursPolicy.dayKey(cursor, calendar: calendar)
            summaries.append(byDay[key] ?? DailySummary(dayKey: key))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDay
        }

        return summaries
    }

    private func writeSummaryCaches(
        upTo date: Date,
        byDay: [String: DailySummary],
        calendar: Calendar,
        paths: AppPaths
    ) throws {
        let generatedAt = Date()
        let monthKey = Self.monthKey(for: date, calendar: calendar)
        let days = Self.monthSummaries(upTo: date, from: byDay, calendar: calendar)
        let monthCache = MonthSummaryCache(
            generatedAt: generatedAt,
            timeZoneIdentifier: calendar.timeZone.identifier,
            month: monthKey,
            totals: SummaryTotals(summaries: days),
            days: days
        )

        let year = calendar.component(.year, from: date)
        let monthRows = Self.yearMonthRows(upTo: date, byDay: byDay, calendar: calendar)
        let yearCache = YearSummaryCache(
            generatedAt: generatedAt,
            timeZoneIdentifier: calendar.timeZone.identifier,
            year: year,
            totals: SummaryTotals(totals: monthRows.map(\.totals)),
            months: monthRows
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try paths.ensureBaseDirectories()
        let monthURL = paths.summariesDirectory.appendingPathComponent("month-\(monthKey).json")
        let yearURL = paths.summariesDirectory.appendingPathComponent("year-\(year).json")
        try encoder.encode(monthCache).write(to: monthURL, options: .atomic)
        try encoder.encode(yearCache).write(to: yearURL, options: .atomic)
    }

    private static func yearMonthRows(
        upTo date: Date,
        byDay: [String: DailySummary],
        calendar: Calendar
    ) -> [MonthSummaryRow] {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1970
        let targetMonth = components.month ?? 1

        return (1...max(1, targetMonth)).map { month in
            let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
            let monthEnd: Date
            if month == targetMonth {
                monthEnd = date
            } else {
                let interval = calendar.dateInterval(of: .month, for: monthStart)
                monthEnd = interval?.end.addingTimeInterval(-1) ?? monthStart
            }
            let key = Self.monthKey(for: monthStart, calendar: calendar)
            let days = Self.monthSummaries(upTo: monthEnd, from: byDay, calendar: calendar)
            return MonthSummaryRow(month: key, totals: SummaryTotals(summaries: days))
        }
    }

    private func logURL(for date: Date, paths: AppPaths) -> URL {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        return paths.logsDirectory.appendingPathComponent(String(format: "events-%04d-%02d.jsonl", year, month))
    }
}

private struct MonthSummaryCache: Codable {
    var schemaVersion = 1
    var generatedAt: Date
    var timeZoneIdentifier: String
    var month: String
    var totals: SummaryTotals
    var days: [DailySummary]
}

private struct YearSummaryCache: Codable {
    var schemaVersion = 1
    var generatedAt: Date
    var timeZoneIdentifier: String
    var year: Int
    var totals: SummaryTotals
    var months: [MonthSummaryRow]
}

private struct MonthSummaryRow: Codable {
    var month: String
    var totals: SummaryTotals
}

private struct SummaryTotals: Codable {
    var focusSessionsCompleted: Int
    var focusMinutes: Int
    var eyeBreaksCompleted: Int
    var eyeBreaksSkipped: Int
    var inferredRests: Int
    var longestContinuousUsageMinutes: Int

    init(summaries: [DailySummary]) {
        focusSessionsCompleted = summaries.reduce(0) { $0 + $1.focusSessionsCompleted }
        focusMinutes = summaries.reduce(0) { $0 + $1.focusMinutes }
        eyeBreaksCompleted = summaries.reduce(0) { $0 + $1.eyeBreaksCompleted }
        eyeBreaksSkipped = summaries.reduce(0) { $0 + $1.eyeBreaksSkipped }
        inferredRests = summaries.reduce(0) { $0 + $1.inferredRests }
        longestContinuousUsageMinutes = summaries.map(\.longestContinuousUsageMinutes).max() ?? 0
    }

    init(totals: [SummaryTotals]) {
        focusSessionsCompleted = totals.reduce(0) { $0 + $1.focusSessionsCompleted }
        focusMinutes = totals.reduce(0) { $0 + $1.focusMinutes }
        eyeBreaksCompleted = totals.reduce(0) { $0 + $1.eyeBreaksCompleted }
        eyeBreaksSkipped = totals.reduce(0) { $0 + $1.eyeBreaksSkipped }
        inferredRests = totals.reduce(0) { $0 + $1.inferredRests }
        longestContinuousUsageMinutes = totals.map(\.longestContinuousUsageMinutes).max() ?? 0
    }
}
