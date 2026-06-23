import EyePomoCore
import Foundation

actor EventStore {
    func append(_ event: EventEnvelope) throws {
        AppPaths.ensureBaseDirectories()
        let url = logURL(for: event.occurredAt)
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

    func loadAllEvents() -> EventLogDecodeResult {
        AppPaths.ensureBaseDirectories()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: AppPaths.logsDirectory,
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

    func regenerateJournal(for day: Date, preferences: AppPreferences, calendar: Calendar) throws -> DailySummary {
        let decoded = loadAllEvents()
        let summary = DailySummaryBuilder.build(events: decoded.events, day: day, calendar: calendar)
        let markdown = MarkdownJournalRenderer.render(
            summary: summary,
            preferences: preferences,
            timeZoneIdentifier: calendar.timeZone.identifier,
            recoveredCorruptFinalLine: decoded.recoveredCorruptFinalLine
        )

        AppPaths.ensureBaseDirectories()
        let url = AppPaths.journalsDirectory.appendingPathComponent("\(summary.dayKey).md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return summary
    }

    private func logURL(for date: Date) -> URL {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        return AppPaths.logsDirectory.appendingPathComponent(String(format: "events-%04d-%02d.jsonl", year, month))
    }
}
