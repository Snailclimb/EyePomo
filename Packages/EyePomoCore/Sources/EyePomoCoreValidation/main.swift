import Foundation
import EyePomoCore

struct ValidationError: Error, CustomStringConvertible {
    var description: String
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw ValidationError(description: message)
    }
}

let formatter = ISO8601DateFormatter()
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
let startDate = formatter.date(from: "2026-06-23T02:00:00Z")!

@MainActor
func initialStateSchedulesEyeBreak() throws {
    let state = AppState.initial(now: AppInstant(milliseconds: 0))
    try check(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 1_200_000), "initial eye break due should be 20 minutes")
    try check(state.preferences.eyeBreakDurationSeconds == 20, "default eye break duration should be 20 seconds")
}

@MainActor
func pomodoroPauseResume() throws {
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))

    _ = AppReducer.reduce(state: &state, event: .user(.startPomodoro), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
    try check(state.pomodoro.phase == .focus, "pomodoro should start focus")
    try check(state.pomodoro.remainingSeconds(at: .init(milliseconds: 60_000)) == 24 * 60, "focus remaining should be deadline-derived")

    _ = AppReducer.reduce(state: &state, event: .user(.pausePomodoro), now: .init(milliseconds: 60_000), wallDate: startDate, calendar: calendar)
    try check(state.pomodoro.runState == .paused, "pomodoro should pause")
    try check(state.pomodoro.remainingWhenPausedSeconds == 24 * 60, "pause should preserve remaining seconds")

    _ = AppReducer.reduce(state: &state, event: .user(.resumePomodoro), now: .init(milliseconds: 100_000), wallDate: startDate, calendar: calendar)
    try check(state.pomodoro.runState == .running, "pomodoro should resume")
    try check(state.pomodoro.remainingSeconds(at: .init(milliseconds: 100_000)) == 24 * 60, "resume should create deadline from paused remaining")
}

@MainActor
func fourthFocusStartsLongBreak() throws {
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
    state.pomodoro.completedFocusCount = 3

    _ = AppReducer.reduce(state: &state, event: .user(.startPomodoro), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
    let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 1_500_000), wallDate: startDate, calendar: calendar)

    try check(state.pomodoro.phase == .longBreak, "fourth focus should enter long break")
    try check(state.pomodoro.completedFocusCount == 4, "completed focus count should increment")
    try check(effects.contains { effect in
        if case .showOverlay(let request) = effect {
            return request.kind == .longBreak && request.durationSeconds == 15 * 60
        }
        return false
    }, "long break should show overlay")
}

@MainActor
func eyeBreakDueNearFocusEndDefers() throws {
    var preferences = AppPreferences(workHoursEnabled: false)
    preferences.eyeBreakIntervalSeconds = 23 * 60
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)

    _ = AppReducer.reduce(state: &state, event: .user(.startPomodoro), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
    let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 1_380_000), wallDate: startDate, calendar: calendar)

    try check(state.eyeBreak.phase == .deferredToPomodoroBreak, "eye break should defer when focus has <= 2 minutes")
    try check(!effects.contains { if case .showOverlay = $0 { return true }; return false }, "deferred eye break should not show overlay")
}

@MainActor
func eyeBreakDueDuringFocusShowsOverlay() throws {
    var preferences = AppPreferences(workHoursEnabled: false)
    preferences.eyeBreakIntervalSeconds = 15 * 60
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)

    _ = AppReducer.reduce(state: &state, event: .user(.startPomodoro), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
    let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 900_000), wallDate: startDate, calendar: calendar)

    try check(state.eyeBreak.phase == .active, "eye break should activate")
    try check(state.pomodoro.phase == .focus && state.pomodoro.runState == .running, "eye break should not pause focus")
    try check(effects.contains { effect in
        if case .showOverlay(let request) = effect {
            return request.kind == .eyeBreak
        }
        return false
    }, "active eye break should show overlay")
}

@MainActor
func pomodoroBreakSatisfiesEyeBreak() throws {
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
    state.eyeBreak.phase = .deferredToPomodoroBreak
    state.eyeBreak.nextDueAt = .init(milliseconds: 0)
    state.pomodoro.phase = .shortBreak
    state.pomodoro.runState = .running
    state.pomodoro.deadline = Deadline(startedAt: .init(milliseconds: 0), durationSeconds: 5 * 60)

    let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 20_000), wallDate: startDate, calendar: calendar)

    try check(state.eyeBreak.phase == .scheduled, "pomodoro break should satisfy deferred eye break")
    try check(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 1_220_000), "eye break interval should reset after pomodoro break satisfaction")
    try check(effects.contains { effect in
        if case .appendEvent(let event) = effect, case .inferredRest(let payload) = event.kind {
            return payload.reason == "pomodoroBreak"
        }
        return false
    }, "pomodoro break satisfaction should log inferred rest")
}

@MainActor
func eyeBreakActionsAreDistinct() throws {
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))

    _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)
    let completeEffects = AppReducer.reduce(state: &state, event: .user(.completeEyeBreak), now: .init(milliseconds: 20_000), wallDate: startDate, calendar: calendar)
    try check(completeEffects.contains { if case .appendEvent(let event) = $0, case .eyeBreakCompleted = event.kind { return true }; return false }, "completion should log eyeBreakCompleted")

    _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 30_000), wallDate: startDate, calendar: calendar)
    let snoozeEffects = AppReducer.reduce(state: &state, event: .user(.snoozeEyeBreak), now: .init(milliseconds: 35_000), wallDate: startDate, calendar: calendar)
    try check(state.eyeBreak.phase == .snoozed, "snooze should enter snoozed phase")
    try check(snoozeEffects.contains { if case .appendEvent(let event) = $0, case .eyeBreakSnoozed = event.kind { return true }; return false }, "snooze should log eyeBreakSnoozed")

    _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 40_000), wallDate: startDate, calendar: calendar)
    let skipEffects = AppReducer.reduce(state: &state, event: .user(.skipEyeBreak), now: .init(milliseconds: 45_000), wallDate: startDate, calendar: calendar)
    try check(skipEffects.contains { if case .appendEvent(let event) = $0, case .eyeBreakSkipped = event.kind { return true }; return false }, "skip should log eyeBreakSkipped")
}

@MainActor
func idleCreatesInferredRest() throws {
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
    let effects = AppReducer.reduce(
        state: &state,
        event: .presence(.idleThresholdReached(idleSeconds: 420)),
        now: .init(milliseconds: 420_000),
        wallDate: startDate,
        calendar: calendar
    )

    try check(state.eyeBreak.phase == .scheduled, "idle should reset eye break schedule")
    try check(effects.contains { effect in
        if case .appendEvent(let event) = effect, case .inferredRest(let payload) = event.kind {
            return payload.idleSeconds == 420
        }
        return false
    }, "idle should log inferred rest")
    try check(!effects.contains { if case .appendEvent(let event) = $0, case .eyeBreakCompleted = event.kind { return true }; return false }, "inferred rest should not count as manual completion")
}

@MainActor
func wakeRefreshesStaleOverlay() throws {
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: AppPreferences(workHoursEnabled: false))
    _ = AppReducer.reduce(state: &state, event: .user(.requestEyeBreakNow), now: .init(milliseconds: 0), wallDate: startDate, calendar: calendar)

    let effects = AppReducer.reduce(state: &state, event: .presence(.wakeDetected), now: .init(milliseconds: 3_600_000), wallDate: startDate, calendar: calendar)

    try check(state.eyeBreak.phase == .scheduled, "wake should schedule next eye break")
    try check(state.presentation.activeOverlay == nil, "wake should clear stale overlay")
    try check(state.eyeBreak.nextDueAt == AppInstant(milliseconds: 4_800_000), "wake should refresh next due")
    try check(effects.contains { if case .dismissOverlay = $0 { return true }; return false }, "wake should dismiss stale overlay")
    try check(!effects.contains { if case .showOverlay = $0 { return true }; return false }, "wake should not replay stale overlay")
}

@MainActor
func workHoursSuppressAutomaticEyeBreak() throws {
    var preferences = AppPreferences()
    preferences.eyeBreakIntervalSeconds = 1
    var state = AppState.initial(now: .init(milliseconds: 0), preferences: preferences)
    let night = formatter.date(from: "2026-06-23T13:00:00Z")!

    let effects = AppReducer.reduce(state: &state, event: .clock(.tick), now: .init(milliseconds: 1_000), wallDate: night, calendar: calendar)

    try check(state.eyeBreak.phase == .suppressed, "outside work hours should suppress automatic eye break")
    try check(!effects.contains { if case .showOverlay = $0 { return true }; return false }, "suppressed eye break should not show overlay")
    try check(effects.contains { if case .appendEvent(let event) = $0, case .workHoursSuppressed = event.kind { return true }; return false }, "suppression should be logged")
}

@MainActor
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

    try check(result.events.count == 1, "decoder should keep valid events")
    try check(result.recoveredCorruptFinalLine, "decoder should mark corrupt final line recovery")
    try check(result.failedLineCount == 1, "decoder should count failed line")
}

@MainActor
func summaryAndMarkdownFromEvents() throws {
    let events = [
        EventEnvelope(occurredAt: startDate, timeZoneIdentifier: "Asia/Shanghai", kind: .pomodoroFocusCompleted(FocusPayload(durationSeconds: 1500, sessionID: UUID())), source: .system),
        EventEnvelope(occurredAt: startDate.addingTimeInterval(60), timeZoneIdentifier: "Asia/Shanghai", kind: .eyeBreakCompleted(EyeBreakPayload(durationSeconds: 20, trigger: "manual")), source: .user),
        EventEnvelope(occurredAt: startDate.addingTimeInterval(120), timeZoneIdentifier: "Asia/Shanghai", kind: .eyeBreakSkipped(EyeBreakPayload(durationSeconds: 20, trigger: "user")), source: .user),
        EventEnvelope(occurredAt: startDate.addingTimeInterval(180), timeZoneIdentifier: "Asia/Shanghai", kind: .inferredRest(InferredRestPayload(idleSeconds: 420, reason: "inputIdle")), source: .system)
    ]

    let summary = DailySummaryBuilder.build(events: events, day: startDate, calendar: calendar)
    let markdown = MarkdownJournalRenderer.render(summary: summary, preferences: AppPreferences(), timeZoneIdentifier: "Asia/Shanghai")

    try check(summary.focusSessionsCompleted == 1, "summary should count focus sessions")
    try check(summary.focusMinutes == 25, "summary should count focus minutes")
    try check(summary.eyeBreaksCompleted == 1, "summary should count eye completions")
    try check(summary.eyeBreaksSkipped == 1, "summary should count skips")
    try check(summary.inferredRests == 1, "summary should count inferred rests")
    try check(markdown.contains("focus_sessions_completed: 1"), "markdown should include frontmatter")
    try check(markdown.contains("## 可供本地 AI 分析的问题"), "markdown should include analysis prompts")
}

let validations: [(String, @MainActor () throws -> Void)] = [
    ("initialStateSchedulesEyeBreak", initialStateSchedulesEyeBreak),
    ("pomodoroPauseResume", pomodoroPauseResume),
    ("fourthFocusStartsLongBreak", fourthFocusStartsLongBreak),
    ("eyeBreakDueNearFocusEndDefers", eyeBreakDueNearFocusEndDefers),
    ("eyeBreakDueDuringFocusShowsOverlay", eyeBreakDueDuringFocusShowsOverlay),
    ("pomodoroBreakSatisfiesEyeBreak", pomodoroBreakSatisfiesEyeBreak),
    ("eyeBreakActionsAreDistinct", eyeBreakActionsAreDistinct),
    ("idleCreatesInferredRest", idleCreatesInferredRest),
    ("wakeRefreshesStaleOverlay", wakeRefreshesStaleOverlay),
    ("workHoursSuppressAutomaticEyeBreak", workHoursSuppressAutomaticEyeBreak),
    ("jsonlDecoderRecoversCorruptFinalLine", jsonlDecoderRecoversCorruptFinalLine),
    ("summaryAndMarkdownFromEvents", summaryAndMarkdownFromEvents)
]

for (name, validation) in validations {
    try validation()
    print("PASS \(name)")
}

print("EyePomoCoreValidation passed \(validations.count) scenarios")
