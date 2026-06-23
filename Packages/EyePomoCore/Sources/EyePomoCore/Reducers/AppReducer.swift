import Foundation

public enum AppReducer {
    public static func reduce(
        state: inout AppState,
        event: AppEvent,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        var effects: [AppEffect] = []

        switch event {
        case .user(let action):
            effects.append(contentsOf: reduceUserAction(action, state: &state, now: now, wallDate: wallDate, calendar: calendar))
        case .clock(.tick):
            effects.append(contentsOf: reduceTick(state: &state, now: now, wallDate: wallDate, calendar: calendar))
        case .presence(let presenceEvent):
            effects.append(contentsOf: reducePresence(presenceEvent, state: &state, now: now, wallDate: wallDate, calendar: calendar))
        case .system(let systemEvent):
            effects.append(contentsOf: reduceSystem(systemEvent, state: &state, now: now, wallDate: wallDate, calendar: calendar))
        }

        if !effects.isEmpty {
            effects.append(.updateStatusItem)
        }
        return effects
    }

    private static func reduceUserAction(
        _ action: UserAction,
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        switch action {
        case .startPomodoro:
            return startFocus(state: &state, now: now, wallDate: wallDate, calendar: calendar, source: .user)
        case .pausePomodoro:
            return pausePomodoro(state: &state, now: now, wallDate: wallDate, calendar: calendar)
        case .resumePomodoro:
            return resumePomodoro(state: &state, now: now, wallDate: wallDate, calendar: calendar)
        case .resetPomodoro:
            state.pomodoro = PomodoroState(completedFocusCount: state.pomodoro.completedFocusCount)
            return [.persistState]
        case .skipPomodoroPhase:
            if state.pomodoro.phase == .focus {
                return completeFocus(state: &state, now: now, wallDate: wallDate, calendar: calendar)
            }
            if state.pomodoro.isBreak {
                return completeBreak(state: &state, now: now, wallDate: wallDate, calendar: calendar)
            }
            return []
        case .endPomodoroBreak:
            return completeBreak(state: &state, now: now, wallDate: wallDate, calendar: calendar)
        case .requestEyeBreakNow:
            return activateEyeBreak(state: &state, now: now, wallDate: wallDate, calendar: calendar, trigger: "manual")
        case .completeEyeBreak:
            return satisfyEyeBreak(
                state: &state,
                now: now,
                wallDate: wallDate,
                calendar: calendar,
                kind: .eyeBreakCompleted(EyeBreakPayload(durationSeconds: state.preferences.eyeBreakDurationSeconds, trigger: "manual")),
                source: .user
            )
        case .snoozeEyeBreak:
            let snooze = state.preferences.snoozeSeconds
            state.eyeBreak.phase = .snoozed
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.nextDueAt = now.adding(seconds: snooze)
            state.presentation.activeOverlay = nil
            return [
                .appendEvent(makeEvent(.eyeBreakSnoozed(SnoozePayload(snoozeSeconds: snooze)), source: .user, wallDate: wallDate, calendar: calendar)),
                .dismissOverlay,
                .persistState,
                .regenerateJournal(wallDate)
            ]
        case .skipEyeBreak:
            let duration = state.preferences.eyeBreakDurationSeconds
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            state.presentation.activeOverlay = nil
            return [
                .appendEvent(makeEvent(.eyeBreakSkipped(EyeBreakPayload(durationSeconds: duration, trigger: "user")), source: .user, wallDate: wallDate, calendar: calendar)),
                .dismissOverlay,
                .persistState,
                .regenerateJournal(wallDate)
            ]
        case .pauseReminders(let seconds):
            state.suppression.pauseUntil = wallDate.addingTimeInterval(TimeInterval(seconds))
            state.presentation.activeOverlay = nil
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.nextDueAt = now.adding(seconds: seconds)
            return [.dismissOverlay, .persistState]
        case .muteRemindersForToday:
            state.suppression.mutedForDate = WorkHoursPolicy.dayKey(wallDate, calendar: calendar)
            state.presentation.activeOverlay = nil
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            return [.dismissOverlay, .persistState]
        case .updatePreferences(let preferences):
            state.preferences = preferences
            state.interruptionPolicy.snoozeSeconds = preferences.snoozeSeconds
            if state.eyeBreak.nextDueAt == nil {
                state.eyeBreak.nextDueAt = now.adding(seconds: preferences.eyeBreakIntervalSeconds)
            }
            return [
                .appendEvent(makeEvent(.settingsChanged(SettingsChangedPayload(preferences: preferences)), source: .user, wallDate: wallDate, calendar: calendar)),
                .persistState,
                .regenerateJournal(wallDate)
            ]
        }
    }

    private static func reduceTick(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        var effects: [AppEffect] = []

        if state.pomodoro.runState == .running, let deadline = state.pomodoro.deadline, deadline.hasExpired(at: now) {
            if state.pomodoro.phase == .focus {
                effects.append(contentsOf: completeFocus(state: &state, now: now, wallDate: wallDate, calendar: calendar))
            } else if state.pomodoro.isBreak {
                effects.append(contentsOf: completeBreak(state: &state, now: now, wallDate: wallDate, calendar: calendar))
            }
        }

        effects.append(contentsOf: maybeSatisfyEyeBreakFromPomodoroBreak(state: &state, now: now, wallDate: wallDate, calendar: calendar))
        effects.append(contentsOf: maybeStartDueEyeBreak(state: &state, now: now, wallDate: wallDate, calendar: calendar))
        return effects
    }

    private static func reducePresence(
        _ event: PresenceEvent,
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        switch event {
        case .sleepStarted:
            state.presence.isScreenAwake = false
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            state.presentation.activeOverlay = nil
            return [
                .appendEvent(makeEvent(.sleepStarted(SystemPayload(detail: "system sleep")), source: .system, wallDate: wallDate, calendar: calendar)),
                .dismissOverlay,
                .persistState
            ]
        case .wakeDetected:
            state.presence.isScreenAwake = true
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            state.presentation.activeOverlay = nil
            return [
                .appendEvent(makeEvent(.wakeDetected(SystemPayload(detail: "system wake")), source: .system, wallDate: wallDate, calendar: calendar)),
                .dismissOverlay,
                .persistState
            ]
        case .screenLocked:
            state.presence.isSessionActive = false
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            state.presentation.activeOverlay = nil
            return [
                .appendEvent(makeEvent(.screenLocked(SystemPayload(detail: "screen locked")), source: .system, wallDate: wallDate, calendar: calendar)),
                .dismissOverlay,
                .persistState
            ]
        case .screenUnlocked:
            state.presence.isSessionActive = true
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            state.presentation.activeOverlay = nil
            return [
                .appendEvent(makeEvent(.screenUnlocked(SystemPayload(detail: "screen unlocked")), source: .system, wallDate: wallDate, calendar: calendar)),
                .dismissOverlay,
                .persistState
            ]
        case .idleThresholdReached(let idleSeconds):
            state.presence.isInputIdle = true
            state.presence.lastInputIdleSeconds = idleSeconds
            if idleSeconds >= state.preferences.idleThresholdSeconds {
                return inferRest(
                    state: &state,
                    now: now,
                    wallDate: wallDate,
                    calendar: calendar,
                    idleSeconds: idleSeconds,
                    reason: "inputIdle"
                )
            }
            return []
        case .userReturned(let idleSeconds):
            state.presence.isInputIdle = false
            state.presence.lastInputIdleSeconds = idleSeconds
            if idleSeconds >= state.preferences.idleThresholdSeconds {
                return inferRest(
                    state: &state,
                    now: now,
                    wallDate: wallDate,
                    calendar: calendar,
                    idleSeconds: idleSeconds,
                    reason: "userReturned"
                )
            }
            return []
        }
    }

    private static func reduceSystem(
        _ event: SystemEvent,
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        switch event {
        case .workHoursStarted:
            if state.eyeBreak.nextDueAt == nil {
                state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            }
            return [.persistState]
        case .workHoursEnded:
            state.presentation.activeOverlay = nil
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            return [.dismissOverlay, .persistState]
        case .screensChanged:
            if let activeOverlay = state.presentation.activeOverlay {
                return [
                    .showOverlay(OverlayRequest(
                        kind: activeOverlay,
                        durationSeconds: state.eyeBreak.remainingSeconds(at: now),
                        message: "看向 6 米外"
                    ))
                ]
            }
            return []
        }
    }

    private static func startFocus(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar,
        source: EventSource
    ) -> [AppEffect] {
        let sessionID = UUID()
        state.pomodoro.phase = .focus
        state.pomodoro.runState = .running
        state.pomodoro.deadline = Deadline(startedAt: now, durationSeconds: state.preferences.focusDurationSeconds)
        state.pomodoro.remainingWhenPausedSeconds = nil
        state.pomodoro.currentSessionID = sessionID

        return [
            .appendEvent(makeEvent(.pomodoroStarted(FocusPayload(durationSeconds: state.preferences.focusDurationSeconds, sessionID: sessionID)), source: source, wallDate: wallDate, calendar: calendar)),
            .persistState,
            .regenerateJournal(wallDate)
        ]
    }

    private static func pausePomodoro(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        guard state.pomodoro.runState == .running else {
            return []
        }
        let remaining = state.pomodoro.remainingSeconds(at: now)
        state.pomodoro.runState = .paused
        state.pomodoro.remainingWhenPausedSeconds = remaining
        state.pomodoro.deadline = nil

        let sessionID = state.pomodoro.currentSessionID ?? UUID()
        return [
            .appendEvent(makeEvent(.pomodoroPaused(FocusPayload(durationSeconds: remaining, sessionID: sessionID)), source: .user, wallDate: wallDate, calendar: calendar)),
            .persistState,
            .regenerateJournal(wallDate)
        ]
    }

    private static func resumePomodoro(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        guard state.pomodoro.runState == .paused else {
            return []
        }
        let remaining = max(1, state.pomodoro.remainingWhenPausedSeconds ?? state.preferences.focusDurationSeconds)
        state.pomodoro.runState = .running
        state.pomodoro.deadline = Deadline(startedAt: now, durationSeconds: remaining)
        state.pomodoro.remainingWhenPausedSeconds = nil

        let sessionID = state.pomodoro.currentSessionID ?? UUID()
        return [
            .appendEvent(makeEvent(.pomodoroResumed(FocusPayload(durationSeconds: remaining, sessionID: sessionID)), source: .user, wallDate: wallDate, calendar: calendar)),
            .persistState,
            .regenerateJournal(wallDate)
        ]
    }

    private static func completeFocus(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        let sessionID = state.pomodoro.currentSessionID ?? UUID()
        state.pomodoro.completedFocusCount += 1
        let nextBreak: PomodoroPhase = state.pomodoro.completedFocusCount % max(1, state.preferences.longBreakEvery) == 0 ? .longBreak : .shortBreak
        let breakDuration = nextBreak == .longBreak ? state.preferences.longBreakDurationSeconds : state.preferences.shortBreakDurationSeconds

        state.pomodoro.phase = nextBreak
        state.pomodoro.runState = .running
        state.pomodoro.deadline = Deadline(startedAt: now, durationSeconds: breakDuration)
        state.pomodoro.remainingWhenPausedSeconds = nil
        state.presentation.activeOverlay = nextBreak == .longBreak ? .longBreak : .shortBreak

        return [
            .appendEvent(makeEvent(.pomodoroFocusCompleted(FocusPayload(durationSeconds: state.preferences.focusDurationSeconds, sessionID: sessionID)), source: .system, wallDate: wallDate, calendar: calendar)),
            .appendEvent(makeEvent(.pomodoroBreakStarted(BreakPayload(phase: nextBreak, durationSeconds: breakDuration, sessionID: sessionID)), source: .system, wallDate: wallDate, calendar: calendar)),
            .showOverlay(OverlayRequest(kind: nextBreak == .longBreak ? .longBreak : .shortBreak, durationSeconds: breakDuration, message: "休息完成后再继续")),
            .persistState,
            .regenerateJournal(wallDate)
        ]
    }

    private static func completeBreak(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        guard state.pomodoro.isBreak else {
            return []
        }
        let phase = state.pomodoro.phase
        let sessionID = state.pomodoro.currentSessionID
        let duration = phase == .longBreak ? state.preferences.longBreakDurationSeconds : state.preferences.shortBreakDurationSeconds

        state.pomodoro.phase = .idle
        state.pomodoro.runState = .idle
        state.pomodoro.deadline = nil
        state.pomodoro.remainingWhenPausedSeconds = nil
        state.pomodoro.currentSessionID = nil
        state.presentation.activeOverlay = nil

        return [
            .appendEvent(makeEvent(.pomodoroBreakCompleted(BreakPayload(phase: phase, durationSeconds: duration, sessionID: sessionID)), source: .system, wallDate: wallDate, calendar: calendar)),
            .dismissOverlay,
            .persistState,
            .regenerateJournal(wallDate)
        ]
    }

    private static func maybeStartDueEyeBreak(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        guard state.preferences.eyeBreakEnabled else {
            return []
        }
        guard state.eyeBreak.phase != .active else {
            return []
        }
        guard state.presence.isSessionActive && state.presence.isScreenAwake && !state.presence.isInputIdle else {
            return []
        }
        guard let dueAt = state.eyeBreak.nextDueAt, now >= dueAt else {
            return []
        }

        if state.suppression.isAutomaticReminderSuppressed(at: wallDate, calendar: calendar) {
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            return [.persistState]
        }

        guard WorkHoursPolicy.isInsideWorkHours(wallDate, calendar: calendar, preferences: state.preferences) else {
            state.eyeBreak.phase = .suppressed
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            return [
                .appendEvent(makeEvent(.workHoursSuppressed(SystemPayload(detail: "outside work hours")), source: .system, wallDate: wallDate, calendar: calendar)),
                .persistState,
                .regenerateJournal(wallDate)
            ]
        }

        if state.pomodoro.isBreak {
            return []
        }

        if state.pomodoro.phase == .focus && state.pomodoro.runState == .running {
            let remaining = state.pomodoro.remainingSeconds(at: now)
            if remaining <= state.interruptionPolicy.mergeWindowSeconds {
                state.eyeBreak.phase = .deferredToPomodoroBreak
                state.eyeBreak.nextDueAt = state.pomodoro.deadline?.endsAt
                return [.persistState]
            }
        }

        return activateEyeBreak(state: &state, now: now, wallDate: wallDate, calendar: calendar, trigger: "scheduled")
    }

    private static func activateEyeBreak(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar,
        trigger: String
    ) -> [AppEffect] {
        let duration = state.preferences.eyeBreakDurationSeconds
        state.eyeBreak.phase = .active
        state.eyeBreak.activeDeadline = Deadline(startedAt: now, durationSeconds: duration)
        state.eyeBreak.nextDueAt = nil
        state.presentation.activeOverlay = .eyeBreak

        return [
            .appendEvent(makeEvent(.eyeBreakDue(EyeBreakPayload(durationSeconds: duration, trigger: trigger)), source: trigger == "manual" ? .user : .system, wallDate: wallDate, calendar: calendar)),
            .showOverlay(OverlayRequest(kind: .eyeBreak, durationSeconds: duration, message: "看向 6 米外")),
            .persistState,
            .regenerateJournal(wallDate)
        ]
    }

    private static func maybeSatisfyEyeBreakFromPomodoroBreak(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar
    ) -> [AppEffect] {
        guard state.interruptionPolicy.pomodoroBreakSatisfiesEyeBreak else {
            return []
        }
        guard state.pomodoro.isBreak, state.pomodoro.runState == .running, let deadline = state.pomodoro.deadline else {
            return []
        }
        guard deadline.elapsedSeconds(at: now) >= state.preferences.eyeBreakDurationSeconds else {
            return []
        }
        guard state.eyeBreak.phase == .deferredToPomodoroBreak || (state.eyeBreak.nextDueAt.map { now >= $0 } ?? false) else {
            return []
        }

        return inferRest(
            state: &state,
            now: now,
            wallDate: wallDate,
            calendar: calendar,
            idleSeconds: state.preferences.eyeBreakDurationSeconds,
            reason: "pomodoroBreak"
        )
    }

    private static func satisfyEyeBreak(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar,
        kind: EventKind,
        source: EventSource
    ) -> [AppEffect] {
        state.eyeBreak.phase = .scheduled
        state.eyeBreak.activeDeadline = nil
        state.eyeBreak.lastSatisfiedAt = now
        state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
        state.presentation.activeOverlay = nil

        return [
            .appendEvent(makeEvent(kind, source: source, wallDate: wallDate, calendar: calendar)),
            .dismissOverlay,
            .persistState,
            .regenerateJournal(wallDate)
        ]
    }

    private static func inferRest(
        state: inout AppState,
        now: AppInstant,
        wallDate: Date,
        calendar: Calendar,
        idleSeconds: Int,
        reason: String
    ) -> [AppEffect] {
        state.eyeBreak.phase = .scheduled
        state.eyeBreak.activeDeadline = nil
        state.eyeBreak.lastSatisfiedAt = now
        state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
        state.presentation.activeOverlay = nil

        return [
            .appendEvent(makeEvent(.inferredRest(InferredRestPayload(idleSeconds: idleSeconds, reason: reason)), source: .system, wallDate: wallDate, calendar: calendar)),
            .dismissOverlay,
            .persistState,
            .regenerateJournal(wallDate)
        ]
    }

    private static func makeEvent(
        _ kind: EventKind,
        source: EventSource,
        wallDate: Date,
        calendar: Calendar
    ) -> EventEnvelope {
        EventEnvelope(
            occurredAt: wallDate,
            timeZoneIdentifier: calendar.timeZone.identifier,
            kind: kind,
            source: source
        )
    }
}
