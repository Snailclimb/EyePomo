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

    @Test("AppPreferences decodes old data with legacy eye-break overlay settings")
    func appPreferencesDecodeOldDataWithLegacyEyeBreakOverlaySettings() throws {
        let json = """
        {
          "eyeBreakEnabled": false,
          "overlayEnabled": true,
          "overlayOpacity": 0.66,
          "focusDurationSeconds": 1800
        }
        """.data(using: .utf8)!

        let preferences = try JSONDecoder().decode(AppPreferences.self, from: json)

        #expect(preferences.eyeBreakEnabled == false)
        #expect(preferences.eyeBreakOverlayEnabled == true)
        #expect(preferences.focusDurationSeconds == 1800)
        #expect(preferences.eyeBreakDurationSeconds == 20)
        #expect(preferences.eyeCareFilterEnabled == false)
        #expect(preferences.eyeCareFilterStrength == 0.18)
        #expect(preferences.preReminderEnabled)
        #expect(preferences.preReminderLeadSeconds == 20)
        #expect(preferences.respectSystemFocus)
        #expect(preferences.reduceFullscreenInterruptions)
        #expect(preferences.maxSnoozesPerEyeBreak == 3)
        #expect(preferences.presentationModeDurationSeconds == 60 * 60)
        #expect(preferences.soundEnabled == false)
        #expect(preferences.soundName == "break-start")
        #expect(preferences.soundVolume == 0.5)
    }

    @Test("Display snapshot hides the next eye break when eye reminders are disabled")
    func displaySnapshotHidesEyeBreakWhenDisabled() {
        let state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(eyeBreakEnabled: false))

        let snapshot = state.displaySnapshot(at: .init(milliseconds: 0))

        #expect(snapshot.statusTitle == "Eye breaks off")
        #expect(snapshot.stateLabel == "眼休已关闭")
        #expect(snapshot.countdown.isEmpty)
        #expect(snapshot.progress == 0)
        #expect(snapshot.accent == .neutral)
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
        preferences.reduceFullscreenInterruptions = true
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)
        state.suppression.isFullscreenActive = true
        let night = ISO8601DateFormatter().date(from: "2026-06-23T13:00:00Z")!

        let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 1_000), wallDate: night, calendar: calendar)

        #expect(state.eyeBreak.phase == .suppressed)
        #expect(!effects.hasAnyOverlay)
        #expect(effects.hasAppendedEvent { if case .workHoursSuppressed = $0.kind { return true }; return false })
        #expect(!effects.hasAppendedEvent { if case .eyeBreakSnoozed = $0.kind { return true }; return false })
    }

    @Test("Preference preview updates state without logging settingsChanged")
    func preferencePreviewDoesNotLogSettingsChanged() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
        var preferences = state.preferences
        preferences.eyeBreakIntervalSeconds = 30 * 60

        let effects = AppReducer.reduce(
            state: &state,
            event: .user(.previewPreferences(preferences)),
            now: .init(milliseconds: 1_000),
            wallDate: startDate,
            calendar: calendar
        )

        #expect(state.preferences.eyeBreakIntervalSeconds == 30 * 60)
        #expect(!effects.hasAppendedEvent { if case .settingsChanged = $0.kind { return true }; return false })
        #expect(!effects.hasPersistState)
    }

    @Test("Preference commit logs one settingsChanged event")
    func preferenceCommitLogsSettingsChanged() {
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
        var preferences = state.preferences
        preferences.preReminderLeadSeconds = 15

        let effects = AppReducer.reduce(
            state: &state,
            event: .user(.commitPreferences(preferences)),
            now: .init(milliseconds: 1_000),
            wallDate: startDate,
            calendar: calendar
        )

        #expect(state.preferences.preReminderLeadSeconds == 15)
        #expect(effects.hasAppendedEvent {
            if case .settingsChanged(let payload) = $0.kind {
                return payload.preferences.preReminderLeadSeconds == 15
            }
            return false
        })
        #expect(effects.hasPersistState)
    }

    @Test("Pre-reminder fires once before an eye break without logging JSONL")
    func preReminderFiresOnceWithoutEvent() {
        var preferences = AppPreferences(workHoursEnabled: false)
        preferences.eyeBreakIntervalSeconds = 60
        preferences.preReminderEnabled = true
        preferences.preReminderLeadSeconds = 20
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)

        let firstEffects = AppReducer.reduce(
            state: &state,
            event: .clock(.tick),
            now: .init(milliseconds: 45_000),
            wallDate: startDate,
            calendar: calendar
        )
        let secondEffects = AppReducer.reduce(
            state: &state,
            event: .clock(.tick),
            now: .init(milliseconds: 50_000),
            wallDate: startDate,
            calendar: calendar
        )

        #expect(firstEffects.hasPreReminder(leadSeconds: 15))
        #expect(!firstEffects.hasAppendedEvent { _ in true })
        #expect(!secondEffects.hasPreReminder)
    }

    @Test("Fullscreen interruptions snooze only up to the configured limit")
    func fullscreenInterruptionSnoozeLimit() {
        var preferences = AppPreferences(workHoursEnabled: false)
        preferences.eyeBreakIntervalSeconds = 60
        preferences.snoozeSeconds = 60
        preferences.maxSnoozesPerEyeBreak = 1
        preferences.reduceFullscreenInterruptions = true
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)
        state.suppression.isFullscreenActive = true

        let snoozeEffects = AppReducer.reduce(
            state: &state,
            event: .clock(.tick),
            now: .init(milliseconds: 60_000),
            wallDate: startDate,
            calendar: calendar
        )

        #expect(state.eyeBreak.phase == .snoozed)
        #expect(state.eyeBreak.snoozeCount == 1)
        #expect(!snoozeEffects.hasAnyOverlay)
        #expect(snoozeEffects.hasAppendedEvent { if case .eyeBreakSnoozed = $0.kind { return true }; return false })

        let dueAgainEffects = AppReducer.reduce(
            state: &state,
            event: .clock(.tick),
            now: .init(milliseconds: 120_000),
            wallDate: startDate,
            calendar: calendar
        )

        #expect(state.eyeBreak.phase == .active)
        #expect(dueAgainEffects.hasOverlay(kind: .eyeBreak))
    }

    @Test("Presentation mode delays automatic eye breaks")
    func presentationModeDelaysAutomaticEyeBreaks() {
        var preferences = AppPreferences(workHoursEnabled: false)
        preferences.eyeBreakIntervalSeconds = 60
        var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)

        let startEffects = AppReducer.reduce(
            state: &state,
            event: .user(.startPresentationMode(seconds: 600)),
            now: .init(milliseconds: 10_000),
            wallDate: startDate,
            calendar: calendar
        )

        #expect(state.suppression.isPresentationModeActive(at: startDate))
        #expect(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 610_000))
        #expect(startEffects.hasDismissOverlay)

        state.eyeBreak.nextDueAt = .init(milliseconds: 20_000)
        let tickEffects = AppReducer.reduce(
            state: &state,
            event: .clock(.tick),
            now: .init(milliseconds: 20_000),
            wallDate: startDate.addingTimeInterval(10),
            calendar: calendar
        )

        #expect(!tickEffects.hasAnyOverlay)
        #expect(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 610_000))
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

    @Test("Daily summary and monthly Markdown journal are derived from events")
    func summaryAndMonthlyMarkdownFromEvents() {
        let events = [
            EventEnvelope(occurredAt: startDate, timeZoneIdentifier: "Asia/Shanghai", kind: .pomodoroFocusCompleted(FocusPayload(durationSeconds: 1500, sessionID: UUID())), source: .system),
            EventEnvelope(occurredAt: startDate.addingTimeInterval(60), timeZoneIdentifier: "Asia/Shanghai", kind: .eyeBreakCompleted(EyeBreakPayload(durationSeconds: 20, trigger: "manual")), source: .user),
            EventEnvelope(occurredAt: startDate.addingTimeInterval(120), timeZoneIdentifier: "Asia/Shanghai", kind: .eyeBreakSkipped(EyeBreakPayload(durationSeconds: 20, trigger: "user")), source: .user),
            EventEnvelope(occurredAt: startDate.addingTimeInterval(180), timeZoneIdentifier: "Asia/Shanghai", kind: .inferredRest(InferredRestPayload(idleSeconds: 420, reason: "inputIdle")), source: .system)
        ]

        let summary = DailySummaryBuilder.build(events: events, day: startDate, calendar: calendar)
        let markdown = MarkdownJournalRenderer.renderMonthly(
            monthKey: "2026-06",
            summaries: [summary],
            preferences: AppPreferences(),
            timeZoneIdentifier: "Asia/Shanghai"
        )

        #expect(summary.focusSessionsCompleted == 1)
        #expect(summary.focusMinutes == 25)
        #expect(summary.eyeBreaksCompleted == 1)
        #expect(summary.eyeBreaksSkipped == 1)
        #expect(summary.inferredRests == 1)
        #expect(markdown.contains("month: 2026-06"))
        #expect(markdown.contains("focus_sessions_completed: 1"))
        #expect(markdown.contains("| 2026-06-23 | 1 | 25 | 1 | 1 | 1 |"))
        #expect(markdown.contains("## 可供本地 AI 分析的问题"))
    }

    @Test("Monthly Markdown journal aggregates multiple daily summaries")
    func monthlyMarkdownAggregatesDailySummaries() {
        let summaries = [
            DailySummary(
                dayKey: "2026-06-23",
                focusSessionsCompleted: 1,
                focusMinutes: 25,
                eyeBreaksCompleted: 2,
                eyeBreaksSkipped: 1,
                inferredRests: 3,
                longestContinuousUsageMinutes: 34
            ),
            DailySummary(
                dayKey: "2026-06-24",
                focusSessionsCompleted: 2,
                focusMinutes: 50,
                eyeBreaksCompleted: 1,
                eyeBreaksSkipped: 0,
                inferredRests: 1,
                longestContinuousUsageMinutes: 18
            )
        ]

        let markdown = MarkdownJournalRenderer.renderMonthly(
            monthKey: "2026-06",
            summaries: summaries,
            preferences: AppPreferences(),
            timeZoneIdentifier: "Asia/Shanghai"
        )

        #expect(markdown.contains("focus_sessions_completed: 3"))
        #expect(markdown.contains("focus_minutes: 75"))
        #expect(markdown.contains("eye_breaks_completed: 3"))
        #expect(markdown.contains("longest_continuous_usage_minutes: 34"))
        #expect(markdown.contains("| 2026-06-24 | 2 | 50 | 1 | 0 | 1 | 18 |"))
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

    var hasPersistState: Bool {
        contains { if case .persistState = $0 { return true }; return false }
    }

    var hasPreReminder: Bool {
        contains { if case .showPreReminder = $0 { return true }; return false }
    }

    func hasPreReminder(leadSeconds: Int) -> Bool {
        contains { effect in
            guard case .showPreReminder(let request) = effect else {
                return false
            }
            return request.leadSeconds == leadSeconds
        }
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
