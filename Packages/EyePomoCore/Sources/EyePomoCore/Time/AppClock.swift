import Foundation

public struct AppInstant: Codable, Sendable, Equatable, Comparable, Hashable {
    public var milliseconds: Int64

    public init(milliseconds: Int64) {
        self.milliseconds = milliseconds
    }

    public static func < (lhs: AppInstant, rhs: AppInstant) -> Bool {
        lhs.milliseconds < rhs.milliseconds
    }

    public func adding(seconds: Int) -> AppInstant {
        AppInstant(milliseconds: milliseconds + Int64(seconds) * 1_000)
    }

    public func seconds(until other: AppInstant) -> Int {
        Int((other.milliseconds - milliseconds) / 1_000)
    }
}

public struct Deadline: Codable, Sendable, Equatable, Hashable {
    public var startedAt: AppInstant
    public var durationSeconds: Int
    public var endsAt: AppInstant

    public init(startedAt: AppInstant, durationSeconds: Int) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.endsAt = startedAt.adding(seconds: durationSeconds)
    }

    public func remainingSeconds(at now: AppInstant) -> Int {
        max(0, now.seconds(until: endsAt))
    }

    public func elapsedSeconds(at now: AppInstant) -> Int {
        min(durationSeconds, max(0, startedAt.seconds(until: now)))
    }

    public var isExpired: Bool {
        false
    }

    public func hasExpired(at now: AppInstant) -> Bool {
        now >= endsAt
    }
}

public protocol AppClock: Sendable {
    var now: AppInstant { get }
}

public struct ManualClock: AppClock, Sendable {
    public var now: AppInstant

    public init(now: AppInstant = AppInstant(milliseconds: 0)) {
        self.now = now
    }
}
