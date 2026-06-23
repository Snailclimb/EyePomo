import Foundation
import Testing
@testable import EyePomoCore

@Suite("EyePomoCore reducer behavior")
struct AppReducerTests {
    private let calendar: Calendar
    private let startDate: Date

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        self.calendar = calendar

        let formatter = ISO8601DateFormatter()
        self.startDate = formatter.date(from: "2026-06-23T02:00:00Z")!
    }

    @Test("Initial state schedules the first eye break")
    func initialStateSchedulesEyeBreak() {
        let state = AppState.initial(now: AppInstant(milliseconds: 0))

        #expect(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 1_200_000))
        #expect(state.preferences.eyeBreakDurationSeconds == 20)
    }

    @Test("Pomodoro pause and resume preserve remaining duration")
    func pomodoroPauseResume() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))

        _ = AppReducer.reduce(state: &state, event: .user(.startPomodoro), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
        #expect(state.pomodoro.phase == .focus)
        #expect(state.pomodoro.remainingSeconds(at: .init(milliseconds: 60_000)) == 24 * 60)

        _ = AppReducer.reduce(state: &state, event: .user(.pausePomodoro), now: .init(milliseconds: 60_000), wallDate: startDate, calendar: calendar)
        #expect(state.pomodoro.runState == .paused)
        #expect(state.pomodoro.remainingWhenPausedSeconds == 24 * 60)

        _ = AppReducer.reduce(state: &state, event: .user(.resumePomodoro), now: .init(milliseconds: 100_000), wallDate: startDate, calendar: calendar)
        #expect(state.pomodoro.runState == .running)
        #expect(state.pomodoro.remainingSeconds(at: .init(milliseconds: 100_000)) == 24 * 60)
    }

    @Test("Fourth completed focus starts a long break")
    func fourthFocusStartsLongBreak() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
        state.pomodoro.completedFocusCount = 3

        _ = AppReducer.reduce(state: &state, event: .user(.startPomodoro), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
        let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 1_500_000), wallDate: startDate, calendar: calendar)

        #expect(state.pomodoro.phase == .longBreak)
        #expect(state.pomodoro.completedFocusCount == 4)
        #expect(effects.hasOverlay(kind: .longBreak, durationSeconds: 15 * 60))
    }

    @Test("Eye break due near focus end defers into pomodoro break")
    func eyeBreakDueNearFocusEndDefers() {
        var preferences = AppPreferences(workHoursEnabled: false)
        preferences.eyeBreakIntervalSeconds = 23 * 60
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)

        _ = AppReducer.reduce(state: &state, event: .user(.startPomodoro), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
        let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 1_380_000), wallDate: startDate, calendar: calendar)

        #expect(state.eyeBreak.phase == .deferredToPomodoroBreak)
        #expect(!effects.hasAnyOverlay)
    }

    @Test("Eye break due during focus shows overlay without pausing focus")
    func eyeBreakDueDuringFocusShowsOverlay() {
        var preferences = AppPreferences(workHoursEnabled: false)
        preferences.eyeBreakIntervalSeconds = 15 * 60
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)

        _ = AppReducer.reduce(state: &state, event: .user(.startPomodoro), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
        let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 900_000), wallDate: startDate, calendar: calendar)

        #expect(state.eyeBreak.phase == .active)
        #expect(state.pomodoro.phase == .focus)
        #expect(state.pomodoro.runState == .running)
        #expect(effects.hasOverlay(kind: .eyeBreak))
    }

    @Test("Pomodoro break can satisfy a deferred eye break")
    func pomodoroBreakSatisfiesEyeBreak() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
        state.eyeBreak.phase = .deferredToPomodoroBreak
        state.eyeBreak.nextDueAt = .init(milliseconds: 0)
        state.pomodoro.phase = .shortBreak
        state.pomodoro.runState = .running
        state.pomodoro.deadline = Deadline(startedAt: .init(milliseconds: 0), durationSeconds: 5 * 60)

        let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 20_000), wallDate: startDate, calendar: calendar)

        #expect(state.eyeBreak.phase == .scheduled)
        #expect(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 1_220_000))
        #expect(effects.hasAppendedEvent {
            if case .inferredRest(let payload) = $0.kind {
                return payload.reason == "pomodoroBreak"
            }
            return false
        })
    }

    @Test("Eye break user actions record distinct events")
    func eyeBreakActionsAreDistinct() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))

        _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
        let completeEffects = AppReducer.reduce(state: &state, event: .user(.completeEyeBreak), now: .init(milliseconds: 20_000), wallDate: startDate, calendar: calendar)
        #expect(completeEffects.hasAppendedEvent { if case .eyeBreakCompleted = $0.kind { return true }; return false })

        _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 30_000), wallDate: startDate, calendar: calendar)
        let snoozeEffects = AppReducer.reduce(state: &state, event: .user(.snoozeEyeBreak), now: .init(milliseconds: 35_000), wallDate: startDate, calendar: calendar)
        #expect(state.eyeBreak.phase == .snoozed)
        #expect(snoozeEffects.hasAppendedEvent { if case .eyeBreakSnoozed = $0.kind { return true }; return false })

        _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 40_000), wallDate: startDate, calendar: calendar)
        let skipEffects = AppReducer.reduce(state: &state, event: .user(.skipEyeBreak), now: .init(milliseconds: 45_000), wallDate: startDate, calendar: calendar)
        #expect(skipEffects.hasAppendedEvent { if case .eyeBreakSkipped = $0.kind { return true }; return false })
    }

    @Test("Active eye break completes when its deadline expires")
    func activeEyeBreakCompletesWhenDeadlineExpires() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))

        _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
        let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 20_000), wallDate: startDate, calendar: calendar)

        #expect(state.eyeBreak.phase == .scheduled)
        #expect(state.eyeBreak.activeDeadline == nil)
        #expect(state.presentation.activeOverlay == nil)
        #expect(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 1_220_000))
        #expect(effects.hasAppendedEvent { event in
            if case .eyeBreakCompleted(let payload) = event.kind {
                return payload.durationSeconds == 20 && payload.trigger == "timer" && event.source == .system
            }
            return false
        })
        #expect(effects.hasDismissOverlay)
    }

    @Test("Idle inference resets eye break timing without manual completion")
    func idleCreatesInferredRest() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
        let effects = AppReducer.reduce(
            state: &state,
            event: .presence(.idleThresholdReached(idleSeconds: 420)),
            now: .init(milliseconds: 420_000),
            wallDate: startDate,
            calendar: calendar
        )

        #expect(state.eyeBreak.phase == .scheduled)
        #expect(effects.hasAppendedEvent {
            if case .inferredRest(let payload) = $0.kind {
                return payload.idleSeconds == 420
            }
            return false
        })
        #expect(!effects.hasAppendedEvent { if case .eyeBreakCompleted = $0.kind { return true }; return false })
    }

    @Test("Wake clears stale overlays and refreshes eye break deadline")
    func wakeRefreshesStaleOverlay() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
        _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)

        let effects = AppReducer.reduce(state: &state, event: .presence(.wakeDetected), now: .init(milliseconds: 3_600_000), wallDate: startDate, calendar: calendar)

        #expect(state.eyeBreak.phase == .scheduled)
        #expect(state.presentation.activeOverlay == nil)
        #expect(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 4_800_000))
        #expect(effects.hasDismissOverlay)
        #expect(!effects.hasAnyOverlay)
    }

    @Test("Work hours suppress automatic eye breaks")
    func workHoursSuppressAutomaticEyeBreak() {
        var preferences = AppPreferences()
        preferences.eyeBreakIntervalSeconds = 1
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)
        let night = ISO8601DateFormatter().date(from: "2026-06-23T13:00:00Z")!

        let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 1_000), wallDate: night, calendar: calendar)

        #expect(state.eyeBreak.phase == .suppressed)
        #expect(!effects.hasAnyOverlay)
        #expect(effects.hasAppendedEvent { if case .workHoursSuppressed = $0.kind { return true }; return false })
    }

    @Test("JSONL decoder recovers a corrupt final line")
    func jsonlDecoderRecoversCorruptFinalLine() throws {
        let event = EventEnvelope(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            occurredAt: startDate,
            timeZoneIdentifier: "Asia/Shanghai",
            kind: .eyeBreakCompleted(EyeBreakPayload(durationSeconds: 20, trigger: "manual")),
            source: .user
        )
        let line = try EventLogCodec.encodeLine(event)
        let result = EventLogCodec.decodeJSONLLines(line + "\n{\"broken\"")

        #expect(result.events.count == 1)
        #expect(result.recoveredCorruptFinalLine)
        #expect(result.failedLineCount == 1)
    }

    @Test("Daily summary and Markdown journal are derived from events")
    func summaryAndMarkdownFromEvents() {
        let events = [
            EventEnvelope(occurredAt: startDate, timeZoneIdentifier: "Asia/Shanghai", kind: .pomodoroFocusCompleted(FocusPayload(durationSeconds: 1500, sessionID: UUID())), source: .system),
            EventEnvelope(occurredAt: startDate.addingTimeInterval(60), timeZoneIdentifier: "Asia/Shanghai", kind: .eyeBreakCompleted(EyeBreakPayload(durationSeconds: 20, trigger: "manual")), source: .user),
            EventEnvelope(occurredAt: startDate.addingTimeInterval(120), timeZoneIdentifier: "Asia/Shanghai", kind: .eyeBreakSkipped(EyeBreakPayload(durationSeconds: 20, trigger: "user")), source: .user),
            EventEnvelope(occurredAt: startDate.addingTimeInterval(180), timeZoneIdentifier: "Asia/Shanghai", kind: .inferredRest(InferredRestPayload(idleSeconds: 420, reason: "inputIdle")), source: .system)
        ]

        let summary = DailySummaryBuilder.build(events: events, day: startDate, calendar: calendar)
        let markdown = MarkdownJournalRenderer.render(summary: summary, preferences: AppPreferences(), timeZoneIdentifier: "Asia/Shanghai")

        #expect(summary.focusSessionsCompleted == 1)
        #expect(summary.focusMinutes == 25)
        #expect(summary.eyeBreaksCompleted == 1)
        #expect(summary.eyeBreaksSkipped == 1)
        #expect(summary.inferredRests == 1)
        #expect(markdown.contains("focus_sessions_completed: 1"))
        #expect(markdown.contains("## 可供本地 AI 分析的问题"))
    }

    @Test("buildAll groups events by day and matches single-day build")
    func buildAllGroupsByDay() {
        let day2 = startDate.addingTimeInterval(86_400)
        let events = [
            EventEnvelope(occurredAt: startDate, timeZoneIdentifier: "Asia/Shanghai", kind: .pomodoroFocusCompleted(FocusPayload(durationSeconds: 1500, sessionID: UUID())), source: .system),
            EventEnvelope(occurredAt: startDate.addingTimeInterval(60), timeZoneIdentifier: "Asia/Shanghai", kind: .eyeBreakCompleted(EyeBreakPayload(durationSeconds: 20, trigger: "manual")), source: .user),
            EventEnvelope(occurredAt: day2, timeZoneIdentifier: "Asia/Shanghai", kind: .pomodoroFocusCompleted(FocusPayload(durationSeconds: 1500, sessionID: UUID())), source: .system),
            EventEnvelope(occurredAt: day2.addingTimeInterval(60), timeZoneIdentifier: "Asia/Shanghai", kind: .pomodoroFocusCompleted(FocusPayload(durationSeconds: 1500, sessionID: UUID())), source: .system)
        ]

        let byDay = DailySummaryBuilder.buildAll(events: events, calendar: calendar)

        #expect(byDay.count == 2)

        let day1Key = WorkHoursPolicy.dayKey(startDate, calendar: calendar)
        let day2Key = WorkHoursPolicy.dayKey(day2, calendar: calendar)
        #expect(byDay[day1Key]?.focusSessionsCompleted == 1)
        #expect(byDay[day1Key]?.eyeBreaksCompleted == 1)
        #expect(byDay[day2Key]?.focusSessionsCompleted == 2)

        // buildAll must produce identical per-day summaries to the single-day build.
        let singleDay1 = DailySummaryBuilder.build(events: events, day: startDate, calendar: calendar)
        let singleDay2 = DailySummaryBuilder.build(events: events, day: day2, calendar: calendar)
        #expect(byDay[day1Key] == singleDay1)
        #expect(byDay[day2Key] == singleDay2)
    }

    @Test("buildAll returns empty for an empty event stream")
    func buildAllEmpty() {
        let byDay = DailySummaryBuilder.buildAll(events: [], calendar: calendar)
        #expect(byDay.isEmpty)
    }
}

private extension [AppEffect] {
    var hasAnyOverlay: Bool {
        contains { if case .showOverlay = $0 { return true }; return false }
    }

    var hasDismissOverlay: Bool {
        contains { if case .dismissOverlay = $0 { return true }; return false }
    }

    func hasOverlay(kind: OverlayKind, durationSeconds: Int? = nil) -> Bool {
        contains { effect in
            guard case .showOverlay(let request) = effect, request.kind == kind else {
                return false
            }

            return durationSeconds.map { request.durationSeconds == $0 } ?? true
        }
    }

    func hasAppendedEvent(matching predicate: (EventEnvelope) -> Bool) -> Bool {
        contains { effect in
            guard case .appendEvent(let event) = effect else {
                return false
            }

            return predicate(event)
        }
    }
}
