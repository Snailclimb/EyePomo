import Foundation

public enum PomodoroPhase: String, Codable, Sendable, Equatable, CaseIterable {
    case idle
    case focus
    case shortBreak
    case longBreak
}

public enum TimerRunState: String, Codable, Sendable, Equatable {
    case idle
    case running
    case paused
}

public struct PomodoroState: Codable, Sendable, Equatable {
    public var phase: PomodoroPhase
    public var runState: TimerRunState
    public var deadline: Deadline?
    public var remainingWhenPausedSeconds: Int?
    public var completedFocusCount: Int
    public var currentSessionID: UUID?

    public init(
        phase: PomodoroPhase = .idle,
        runState: TimerRunState = .idle,
        deadline: Deadline? = nil,
        remainingWhenPausedSeconds: Int? = nil,
        completedFocusCount: Int = 0,
        currentSessionID: UUID? = nil
    ) {
        self.phase = phase
        self.runState = runState
        self.deadline = deadline
        self.remainingWhenPausedSeconds = remainingWhenPausedSeconds
        self.completedFocusCount = completedFocusCount
        self.currentSessionID = currentSessionID
    }

    public func remainingSeconds(at now: AppInstant) -> Int {
        switch runState {
        case .idle:
            return 0
        case .paused:
            return remainingWhenPausedSeconds ?? 0
        case .running:
            return deadline?.remainingSeconds(at: now) ?? 0
        }
    }

    public var isBreak: Bool {
        phase == .shortBreak || phase == .longBreak
    }
}

public enum EyeBreakPhase: String, Codable, Sendable, Equatable {
    case scheduled
    case active
    case snoozed
    case deferredToPomodoroBreak
    case suppressed
}

public struct EyeBreakState: Codable, Sendable, Equatable {
    public var phase: EyeBreakPhase
    public var nextDueAt: AppInstant?
    public var activeDeadline: Deadline?
    public var lastSatisfiedAt: AppInstant?
    public var lastSuppressedAt: AppInstant?
    public var preReminderShownForDueAt: AppInstant?
    public var snoozeCount: Int

    public init(
        phase: EyeBreakPhase = .scheduled,
        nextDueAt: AppInstant? = nil,
        activeDeadline: Deadline? = nil,
        lastSatisfiedAt: AppInstant? = nil,
        lastSuppressedAt: AppInstant? = nil,
        preReminderShownForDueAt: AppInstant? = nil,
        snoozeCount: Int = 0
    ) {
        self.phase = phase
        self.nextDueAt = nextDueAt
        self.activeDeadline = activeDeadline
        self.lastSatisfiedAt = lastSatisfiedAt
        self.lastSuppressedAt = lastSuppressedAt
        self.preReminderShownForDueAt = preReminderShownForDueAt
        self.snoozeCount = snoozeCount
    }

    public func remainingSeconds(at now: AppInstant) -> Int {
        if phase == .active, let activeDeadline {
            return activeDeadline.remainingSeconds(at: now)
        }
        guard let nextDueAt else {
            return 0
        }
        return max(0, now.seconds(until: nextDueAt))
    }

    private enum CodingKeys: String, CodingKey {
        case phase
        case nextDueAt
        case activeDeadline
        case lastSatisfiedAt
        case lastSuppressedAt
        case preReminderShownForDueAt
        case snoozeCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            phase: try container.decodeIfPresent(EyeBreakPhase.self, forKey: .phase) ?? .scheduled,
            nextDueAt: try container.decodeIfPresent(AppInstant.self, forKey: .nextDueAt),
            activeDeadline: try container.decodeIfPresent(Deadline.self, forKey: .activeDeadline),
            lastSatisfiedAt: try container.decodeIfPresent(AppInstant.self, forKey: .lastSatisfiedAt),
            lastSuppressedAt: try container.decodeIfPresent(AppInstant.self, forKey: .lastSuppressedAt),
            preReminderShownForDueAt: try container.decodeIfPresent(AppInstant.self, forKey: .preReminderShownForDueAt),
            snoozeCount: try container.decodeIfPresent(Int.self, forKey: .snoozeCount) ?? 0
        )
    }
}

public struct PresenceState: Codable, Sendable, Equatable {
    public var isInputIdle: Bool
    public var lastInputIdleSeconds: Int
    public var isSessionActive: Bool
    public var isScreenAwake: Bool

    public init(
        isInputIdle: Bool = false,
        lastInputIdleSeconds: Int = 0,
        isSessionActive: Bool = true,
        isScreenAwake: Bool = true
    ) {
        self.isInputIdle = isInputIdle
        self.lastInputIdleSeconds = lastInputIdleSeconds
        self.isSessionActive = isSessionActive
        self.isScreenAwake = isScreenAwake
    }
}

public struct SuppressionState: Codable, Sendable, Equatable {
    public var pauseUntil: Date?
    public var mutedForDate: String?
    public var presentationModeUntil: Date?
    public var isFullscreenActive: Bool

    public init(
        pauseUntil: Date? = nil,
        mutedForDate: String? = nil,
        presentationModeUntil: Date? = nil,
        isFullscreenActive: Bool = false
    ) {
        self.pauseUntil = pauseUntil
        self.mutedForDate = mutedForDate
        self.presentationModeUntil = presentationModeUntil
        self.isFullscreenActive = isFullscreenActive
    }

    public func isAutomaticReminderSuppressed(at date: Date, calendar: Calendar) -> Bool {
        if let pauseUntil, date < pauseUntil {
            return true
        }
        if mutedForDate == WorkHoursPolicy.dayKey(date, calendar: calendar) {
            return true
        }
        if isPresentationModeActive(at: date) {
            return true
        }
        return false
    }

    public func isPresentationModeActive(at date: Date) -> Bool {
        guard let presentationModeUntil else {
            return false
        }
        return date < presentationModeUntil
    }

    public func presentationModeRemainingSeconds(at date: Date) -> Int {
        guard let presentationModeUntil, date < presentationModeUntil else {
            return 0
        }
        return max(0, Int(ceil(presentationModeUntil.timeIntervalSince(date))))
    }

    private enum CodingKeys: String, CodingKey {
        case pauseUntil
        case mutedForDate
        case presentationModeUntil
        case isFullscreenActive
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pauseUntil: try container.decodeIfPresent(Date.self, forKey: .pauseUntil),
            mutedForDate: try container.decodeIfPresent(String.self, forKey: .mutedForDate),
            presentationModeUntil: try container.decodeIfPresent(Date.self, forKey: .presentationModeUntil),
            isFullscreenActive: try container.decodeIfPresent(Bool.self, forKey: .isFullscreenActive) ?? false
        )
    }
}

public enum OverlayKind: String, Codable, Sendable, Equatable {
    case eyeBreak
    case shortBreak
    case longBreak
}

public struct PresentationState: Codable, Sendable, Equatable {
    public var activeOverlay: OverlayKind?

    public init(activeOverlay: OverlayKind? = nil) {
        self.activeOverlay = activeOverlay
    }
}

public struct AppState: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var preferences: AppPreferences
    public var interruptionPolicy: InterruptionPolicy
    public var pomodoro: PomodoroState
    public var eyeBreak: EyeBreakState
    public var presence: PresenceState
    public var suppression: SuppressionState
    public var presentation: PresentationState

    public init(
        schemaVersion: Int = 1,
        preferences: AppPreferences = AppPreferences(),
        interruptionPolicy: InterruptionPolicy = InterruptionPolicy(),
        pomodoro: PomodoroState = PomodoroState(),
        eyeBreak: EyeBreakState = EyeBreakState(),
        presence: PresenceState = PresenceState(),
        suppression: SuppressionState = SuppressionState(),
        presentation: PresentationState = PresentationState()
    ) {
        self.schemaVersion = schemaVersion
        self.preferences = preferences
        self.interruptionPolicy = interruptionPolicy
        self.pomodoro = pomodoro
        self.eyeBreak = eyeBreak
        self.presence = presence
        self.suppression = suppression
        self.presentation = presentation
    }

    public static func initial(now: AppInstant, preferences: AppPreferences = AppPreferences()) -> AppState {
        var state = AppState(preferences: preferences)
        state.eyeBreak.nextDueAt = now.adding(seconds: preferences.eyeBreakIntervalSeconds)
        return state
    }
}

public struct DisplaySnapshot: Sendable, Equatable {
    public var statusTitle: String
    public var stateLabel: String
    public var countdown: String
    public var progress: Double
    public var primaryAction: UserAction
    public var primaryTitle: String
    public var accent: DisplayAccent

    public init(
        statusTitle: String,
        stateLabel: String,
        countdown: String,
        progress: Double,
        primaryAction: UserAction,
        primaryTitle: String,
        accent: DisplayAccent
    ) {
        self.statusTitle = statusTitle
        self.stateLabel = stateLabel
        self.countdown = countdown
        self.progress = progress
        self.primaryAction = primaryAction
        self.primaryTitle = primaryTitle
        self.accent = accent
    }
}

public enum DisplayAccent: String, Sendable, Equatable {
    case teal
    case tomato
    case neutral
}

public extension AppState {
    func displaySnapshot(at now: AppInstant) -> DisplaySnapshot {
        if pomodoro.runState == .paused {
            let remaining = pomodoro.remainingSeconds(at: now)
            return DisplaySnapshot(
                statusTitle: "Paused",
                stateLabel: "已暂停",
                countdown: Self.format(seconds: remaining),
                progress: progress(remaining: remaining),
                primaryAction: .resumePomodoro,
                primaryTitle: "继续",
                accent: .neutral
            )
        }

        if pomodoro.runState == .running {
            let remaining = pomodoro.remainingSeconds(at: now)
            switch pomodoro.phase {
            case .focus:
                return DisplaySnapshot(
                    statusTitle: "🍅 \(Self.format(seconds: remaining))",
                    stateLabel: "专注中",
                    countdown: Self.format(seconds: remaining),
                    progress: progress(remaining: remaining),
                    primaryAction: .pausePomodoro,
                    primaryTitle: "暂停",
                    accent: .tomato
                )
            case .shortBreak, .longBreak:
                return DisplaySnapshot(
                    statusTitle: "☕ \(Self.format(seconds: remaining))",
                    stateLabel: pomodoro.phase == .shortBreak ? "短休中" : "长休中",
                    countdown: Self.format(seconds: remaining),
                    progress: progress(remaining: remaining),
                    primaryAction: .endPomodoroBreak,
                    primaryTitle: "结束休息",
                    accent: .teal
                )
            case .idle:
                break
            }
        }

        guard preferences.eyeBreakEnabled else {
            return DisplaySnapshot(
                statusTitle: "Eye breaks off",
                stateLabel: "眼休已关闭",
                countdown: "",
                progress: 0,
                primaryAction: .startPomodoro,
                primaryTitle: "开始专注",
                accent: .neutral
            )
        }

        let remaining = eyeBreak.remainingSeconds(at: now)
        return DisplaySnapshot(
            statusTitle: "👁 \(Self.format(seconds: remaining))",
            stateLabel: "下一次眼休",
            countdown: Self.format(seconds: remaining),
            progress: eyeBreakProgress(remaining: remaining),
            primaryAction: .startPomodoro,
            primaryTitle: "开始专注",
            accent: .teal
        )
    }

    static func format(seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    private func progress(remaining: Int) -> Double {
        let total: Int
        switch pomodoro.phase {
        case .focus:
            total = preferences.focusDurationSeconds
        case .shortBreak:
            total = preferences.shortBreakDurationSeconds
        case .longBreak:
            total = preferences.longBreakDurationSeconds
        case .idle:
            total = 1
        }
        return min(1, max(0, 1 - Double(remaining) / Double(max(1, total))))
    }

    private func eyeBreakProgress(remaining: Int) -> Double {
        min(1, max(0, 1 - Double(remaining) / Double(max(1, preferences.eyeBreakIntervalSeconds))))
    }
}
