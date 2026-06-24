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
    case startPresentationMode(seconds: Int)
    case endPresentationMode
    case previewPreferences(AppPreferences)
    case commitPreferences(AppPreferences)
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
    case fullscreenActivityChanged(isActive: Bool)
}

public enum AppEffect: Sendable, Equatable {
    case showOverlay(OverlayRequest)
    case showPreReminder(PreReminderRequest)
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

public struct PreReminderRequest: Codable, Sendable, Equatable {
    public var leadSeconds: Int
    public var message: String

    public init(leadSeconds: Int, message: String) {
        self.leadSeconds = leadSeconds
        self.message = message
    }
}
