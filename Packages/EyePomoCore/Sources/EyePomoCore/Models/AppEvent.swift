import Foundation

public enum AppEvent: Sendable, Equatable {
    case user(UserAction)
    case clock(ClockEvent)
    case presence(PresenceEvent)
    case system(SystemEvent)
}

public enum UserAction: Sendable, Equatable {
    case startPomodoro
    case pausePomodoro
    case resumePomodoro
    case resetPomodoro
    case skipPomodoroPhase
    case endPomodoroBreak
    case requestEyeBreakNow
    case completeEyeBreak
    case snoozeEyeBreak
    case skipEyeBreak
    case pauseReminders(seconds: Int)
    case muteRemindersForToday
    case updatePreferences(AppPreferences)
}

public enum ClockEvent: Sendable, Equatable {
    case tick
}

public enum PresenceEvent: Sendable, Equatable {
    case sleepStarted
    case wakeDetected
    case screenLocked
    case screenUnlocked
    case idleThresholdReached(idleSeconds: Int)
    case userReturned(idleSeconds: Int)
}

public enum SystemEvent: Sendable, Equatable {
    case workHoursStarted
    case workHoursEnded
    case screensChanged
}

public enum AppEffect: Sendable, Equatable {
    case showOverlay(OverlayRequest)
    case dismissOverlay
    case appendEvent(EventEnvelope)
    case persistState
    case updateStatusItem
    case regenerateJournal(Date)
}

public struct OverlayRequest: Codable, Sendable, Equatable {
    public var kind: OverlayKind
    public var durationSeconds: Int
    public var message: String

    public init(kind: OverlayKind, durationSeconds: Int, message: String) {
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.message = message
    }
}
