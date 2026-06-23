import Foundation

public struct AppPreferences: Codable, Sendable, Equatable {
    public var eyeBreakEnabled: Bool
    public var eyeBreakIntervalSeconds: Int
    public var eyeBreakDurationSeconds: Int
    public var snoozeSeconds: Int
    public var overlayEnabled: Bool
    public var notificationsEnabled: Bool
    public var focusDurationSeconds: Int
    public var shortBreakDurationSeconds: Int
    public var longBreakDurationSeconds: Int
    public var longBreakEvery: Int
    public var workHoursEnabled: Bool
    public var workStartMinuteOfDay: Int
    public var workEndMinuteOfDay: Int
    public var idleThresholdSeconds: Int
    public var launchAtLogin: Bool
    public var overlayOpacity: Double

    public init(
        eyeBreakEnabled: Bool = true,
        eyeBreakIntervalSeconds: Int = 20 * 60,
        eyeBreakDurationSeconds: Int = 20,
        snoozeSeconds: Int = 5 * 60,
        overlayEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        focusDurationSeconds: Int = 25 * 60,
        shortBreakDurationSeconds: Int = 5 * 60,
        longBreakDurationSeconds: Int = 15 * 60,
        longBreakEvery: Int = 4,
        workHoursEnabled: Bool = true,
        workStartMinuteOfDay: Int = 9 * 60,
        workEndMinuteOfDay: Int = 18 * 60,
        idleThresholdSeconds: Int = 3 * 60,
        launchAtLogin: Bool = false,
        overlayOpacity: Double = 0.82
    ) {
        self.eyeBreakEnabled = eyeBreakEnabled
        self.eyeBreakIntervalSeconds = eyeBreakIntervalSeconds
        self.eyeBreakDurationSeconds = eyeBreakDurationSeconds
        self.snoozeSeconds = snoozeSeconds
        self.overlayEnabled = overlayEnabled
        self.notificationsEnabled = notificationsEnabled
        self.focusDurationSeconds = focusDurationSeconds
        self.shortBreakDurationSeconds = shortBreakDurationSeconds
        self.longBreakDurationSeconds = longBreakDurationSeconds
        self.longBreakEvery = longBreakEvery
        self.workHoursEnabled = workHoursEnabled
        self.workStartMinuteOfDay = workStartMinuteOfDay
        self.workEndMinuteOfDay = workEndMinuteOfDay
        self.idleThresholdSeconds = idleThresholdSeconds
        self.launchAtLogin = launchAtLogin
        self.overlayOpacity = overlayOpacity
    }
}

public struct InterruptionPolicy: Codable, Sendable, Equatable {
    public var mergeWindowSeconds: Int
    public var eyeBreakPausesFocus: Bool
    public var pomodoroBreakSatisfiesEyeBreak: Bool
    public var snoozeSeconds: Int

    public init(
        mergeWindowSeconds: Int = 120,
        eyeBreakPausesFocus: Bool = false,
        pomodoroBreakSatisfiesEyeBreak: Bool = true,
        snoozeSeconds: Int = 300
    ) {
        self.mergeWindowSeconds = mergeWindowSeconds
        self.eyeBreakPausesFocus = eyeBreakPausesFocus
        self.pomodoroBreakSatisfiesEyeBreak = pomodoroBreakSatisfiesEyeBreak
        self.snoozeSeconds = snoozeSeconds
    }
}

public enum WorkHoursPolicy {
    public static func isInsideWorkHours(
        _ date: Date,
        calendar: Calendar,
        preferences: AppPreferences
    ) -> Bool {
        guard preferences.workHoursEnabled else {
            return true
        }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let start = preferences.workStartMinuteOfDay
        let end = preferences.workEndMinuteOfDay

        if start == end {
            return true
        }

        if start < end {
            return minute >= start && minute < end
        }

        return minute >= start || minute < end
    }

    public static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
