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
        let summary = DailySummaryBuilder.build(events: decoded.events, day: day, calendar: calendar)
        let markdown = MarkdownJournalRenderer.render(
            summary: summary,
            preferences: preferences,
            timeZoneIdentifier: calendar.timeZone.identifier,
            recoveredCorruptFinalLine: decoded.recoveredCorruptFinalLine
        )

        try paths.ensureBaseDirectories()
        let url = paths.journalsDirectory.appendingPathComponent("\(summary.dayKey).md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
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

    private func logURL(for date: Date, paths: AppPaths) -> URL {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        return paths.logsDirectory.appendingPathComponent(String(format: "events-%04d-%02d.jsonl", year, month))
    }
}
