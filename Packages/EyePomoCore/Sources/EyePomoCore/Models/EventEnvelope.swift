import Foundation

public struct EventEnvelope: Codable, Sendable, Equatable, Identifiable {
    public var schemaVersion: Int
    public var id: UUID
    public var occurredAt: Date
    public var timeZoneIdentifier: String
    public var kind: EventKind
    public var source: EventSource

    public init(
        schemaVersion: Int = 1,
        id: UUID = UUID(),
        occurredAt: Date,
        timeZoneIdentifier: String,
        kind: EventKind,
        source: EventSource
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.occurredAt = occurredAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.kind = kind
        self.source = source
    }
}

public enum EventSource: String, Codable, Sendable, Equatable {
    case user
    case system
    case recovery
}

public enum EventKind: Codable, Sendable, Equatable {
    case eyeBreakDue(EyeBreakPayload)
    case eyeBreakCompleted(EyeBreakPayload)
    case eyeBreakSkipped(EyeBreakPayload)
    case eyeBreakSnoozed(SnoozePayload)
    case inferredRest(InferredRestPayload)
    case pomodoroStarted(FocusPayload)
    case pomodoroPaused(FocusPayload)
    case pomodoroResumed(FocusPayload)
    case pomodoroFocusCompleted(FocusPayload)
    case pomodoroBreakStarted(BreakPayload)
    case pomodoroBreakCompleted(BreakPayload)
    case workHoursSuppressed(SystemPayload)
    case sleepStarted(SystemPayload)
    case wakeDetected(SystemPayload)
    case screenLocked(SystemPayload)
    case screenUnlocked(SystemPayload)
    case settingsChanged(SettingsChangedPayload)
}

public struct EyeBreakPayload: Codable, Sendable, Equatable {
    public var durationSeconds: Int
    public var trigger: String

    public init(durationSeconds: Int, trigger: String) {
        self.durationSeconds = durationSeconds
        self.trigger = trigger
    }
}

public struct SnoozePayload: Codable, Sendable, Equatable {
    public var snoozeSeconds: Int

    public init(snoozeSeconds: Int) {
        self.snoozeSeconds = snoozeSeconds
    }
}

public struct InferredRestPayload: Codable, Sendable, Equatable {
    public var idleSeconds: Int
    public var reason: String

    public init(idleSeconds: Int, reason: String) {
        self.idleSeconds = idleSeconds
        self.reason = reason
    }
}

public struct FocusPayload: Codable, Sendable, Equatable {
    public var durationSeconds: Int
    public var sessionID: UUID

    public init(durationSeconds: Int, sessionID: UUID) {
        self.durationSeconds = durationSeconds
        self.sessionID = sessionID
    }
}

public struct BreakPayload: Codable, Sendable, Equatable {
    public var phase: PomodoroPhase
    public var durationSeconds: Int
    public var sessionID: UUID?

    public init(phase: PomodoroPhase, durationSeconds: Int, sessionID: UUID?) {
        self.phase = phase
        self.durationSeconds = durationSeconds
        self.sessionID = sessionID
    }
}

public struct SystemPayload: Codable, Sendable, Equatable {
    public var detail: String

    public init(detail: String) {
        self.detail = detail
    }
}

public struct SettingsChangedPayload: Codable, Sendable, Equatable {
    public var preferences: AppPreferences

    public init(preferences: AppPreferences) {
        self.preferences = preferences
    }
}

public struct EventLogDecodeResult: Sendable, Equatable {
    public var events: [EventEnvelope]
    public var recoveredCorruptFinalLine: Bool
    public var failedLineCount: Int

    public init(events: [EventEnvelope], recoveredCorruptFinalLine: Bool, failedLineCount: Int) {
        self.events = events
        self.recoveredCorruptFinalLine = recoveredCorruptFinalLine
        self.failedLineCount = failedLineCount
    }
}

public enum EventLogCodec {
    public static func encodeLine(_ event: EventEnvelope) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        return String(decoding: data, as: UTF8.self)
    }

    public static func decodeJSONLLines(_ text: String) -> EventLogDecodeResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var events: [EventEnvelope] = []
        var failed = 0
        var recoveredFinal = false

        for (index, line) in rawLines.enumerated() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            do {
                let data = Data(String(line).utf8)
                events.append(try decoder.decode(EventEnvelope.self, from: data))
            } catch {
                failed += 1
                if index == rawLines.count - 1 {
                    recoveredFinal = true
                }
            }
        }

        return EventLogDecodeResult(
            events: events,
            recoveredCorruptFinalLine: recoveredFinal,
            failedLineCount: failed
        )
    }
}
