import Foundation

public struct AppPreferences: Codable, Sendable, Equatable {
    public var eyeBreakEnabled: Bool
    public var eyeBreakIntervalSeconds: Int
    public var eyeBreakDurationSeconds: Int
    public var snoozeSeconds: Int
    public var eyeBreakOverlayEnabled: Bool
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
    public var eyeCareFilterEnabled: Bool
    public var eyeCareFilterStrength: Double
    public var preReminderEnabled: Bool
    public var preReminderLeadSeconds: Int
    public var respectSystemFocus: Bool
    public var reduceFullscreenInterruptions: Bool
    public var maxSnoozesPerEyeBreak: Int
    public var presentationModeDurationSeconds: Int
    public var soundEnabled: Bool
    public var eyeBreakStartSoundName: String
    public var focusStartSoundName: String
    public var focusCompleteSoundName: String
    public var breakCompleteSoundName: String
    public var soundVolume: Double

    public var soundName: String {
        get { eyeBreakStartSoundName }
        set { eyeBreakStartSoundName = newValue }
    }

    public init(
        eyeBreakEnabled: Bool = true,
        eyeBreakIntervalSeconds: Int = 20 * 60,
        eyeBreakDurationSeconds: Int = 20,
        snoozeSeconds: Int = 5 * 60,
        eyeBreakOverlayEnabled: Bool = true,
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
        eyeCareFilterEnabled: Bool = false,
        eyeCareFilterStrength: Double = 0.18,
        preReminderEnabled: Bool = true,
        preReminderLeadSeconds: Int = 20,
        respectSystemFocus: Bool = true,
        reduceFullscreenInterruptions: Bool = true,
        maxSnoozesPerEyeBreak: Int = 3,
        presentationModeDurationSeconds: Int = 60 * 60,
        soundEnabled: Bool = false,
        soundName: String? = nil,
        eyeBreakStartSoundName: String = "break-start",
        focusStartSoundName: String = "focus-complete-soft",
        focusCompleteSoundName: String = "focus-complete",
        breakCompleteSoundName: String = "break-complete",
        soundVolume: Double = 0.5
    ) {
        self.eyeBreakEnabled = eyeBreakEnabled
        self.eyeBreakIntervalSeconds = eyeBreakIntervalSeconds
        self.eyeBreakDurationSeconds = eyeBreakDurationSeconds
        self.snoozeSeconds = snoozeSeconds
        self.eyeBreakOverlayEnabled = eyeBreakOverlayEnabled
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
        self.eyeCareFilterEnabled = eyeCareFilterEnabled
        self.eyeCareFilterStrength = eyeCareFilterStrength
        self.preReminderEnabled = preReminderEnabled
        self.preReminderLeadSeconds = preReminderLeadSeconds
        self.respectSystemFocus = respectSystemFocus
        self.reduceFullscreenInterruptions = reduceFullscreenInterruptions
        self.maxSnoozesPerEyeBreak = maxSnoozesPerEyeBreak
        self.presentationModeDurationSeconds = presentationModeDurationSeconds
        self.soundEnabled = soundEnabled
        self.eyeBreakStartSoundName = soundName ?? eyeBreakStartSoundName
        self.focusStartSoundName = focusStartSoundName
        self.focusCompleteSoundName = focusCompleteSoundName
        self.breakCompleteSoundName = breakCompleteSoundName
        self.soundVolume = soundVolume
    }

    private enum CodingKeys: String, CodingKey {
        case eyeBreakEnabled
        case eyeBreakIntervalSeconds
        case eyeBreakDurationSeconds
        case snoozeSeconds
        case eyeBreakOverlayEnabled
        case overlayEnabled
        case notificationsEnabled
        case focusDurationSeconds
        case shortBreakDurationSeconds
        case longBreakDurationSeconds
        case longBreakEvery
        case workHoursEnabled
        case workStartMinuteOfDay
        case workEndMinuteOfDay
        case idleThresholdSeconds
        case launchAtLogin
        case eyeCareFilterEnabled
        case eyeCareFilterStrength
        case preReminderEnabled
        case preReminderLeadSeconds
        case respectSystemFocus
        case reduceFullscreenInterruptions
        case maxSnoozesPerEyeBreak
        case presentationModeDurationSeconds
        case soundEnabled
        case soundName
        case eyeBreakStartSoundName
        case focusStartSoundName
        case focusCompleteSoundName
        case breakCompleteSoundName
        case soundVolume
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacySoundName = try container.decodeIfPresent(String.self, forKey: .soundName)
        self.init(
            eyeBreakEnabled: try container.decodeIfPresent(Bool.self, forKey: .eyeBreakEnabled) ?? true,
            eyeBreakIntervalSeconds: try container.decodeIfPresent(Int.self, forKey: .eyeBreakIntervalSeconds) ?? 20 * 60,
            eyeBreakDurationSeconds: try container.decodeIfPresent(Int.self, forKey: .eyeBreakDurationSeconds) ?? 20,
            snoozeSeconds: try container.decodeIfPresent(Int.self, forKey: .snoozeSeconds) ?? 5 * 60,
            eyeBreakOverlayEnabled: try container.decodeIfPresent(Bool.self, forKey: .eyeBreakOverlayEnabled)
                ?? container.decodeIfPresent(Bool.self, forKey: .overlayEnabled)
                ?? true,
            notificationsEnabled: try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false,
            focusDurationSeconds: try container.decodeIfPresent(Int.self, forKey: .focusDurationSeconds) ?? 25 * 60,
            shortBreakDurationSeconds: try container.decodeIfPresent(Int.self, forKey: .shortBreakDurationSeconds) ?? 5 * 60,
            longBreakDurationSeconds: try container.decodeIfPresent(Int.self, forKey: .longBreakDurationSeconds) ?? 15 * 60,
            longBreakEvery: try container.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? 4,
            workHoursEnabled: try container.decodeIfPresent(Bool.self, forKey: .workHoursEnabled) ?? true,
            workStartMinuteOfDay: try container.decodeIfPresent(Int.self, forKey: .workStartMinuteOfDay) ?? 9 * 60,
            workEndMinuteOfDay: try container.decodeIfPresent(Int.self, forKey: .workEndMinuteOfDay) ?? 18 * 60,
            idleThresholdSeconds: try container.decodeIfPresent(Int.self, forKey: .idleThresholdSeconds) ?? 3 * 60,
            launchAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false,
            eyeCareFilterEnabled: try container.decodeIfPresent(Bool.self, forKey: .eyeCareFilterEnabled) ?? false,
            eyeCareFilterStrength: try container.decodeIfPresent(Double.self, forKey: .eyeCareFilterStrength) ?? 0.18,
            preReminderEnabled: try container.decodeIfPresent(Bool.self, forKey: .preReminderEnabled) ?? true,
            preReminderLeadSeconds: try container.decodeIfPresent(Int.self, forKey: .preReminderLeadSeconds) ?? 20,
            respectSystemFocus: try container.decodeIfPresent(Bool.self, forKey: .respectSystemFocus) ?? true,
            reduceFullscreenInterruptions: try container.decodeIfPresent(Bool.self, forKey: .reduceFullscreenInterruptions) ?? true,
            maxSnoozesPerEyeBreak: try container.decodeIfPresent(Int.self, forKey: .maxSnoozesPerEyeBreak) ?? 3,
            presentationModeDurationSeconds: try container.decodeIfPresent(Int.self, forKey: .presentationModeDurationSeconds) ?? 60 * 60,
            soundEnabled: try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false,
            eyeBreakStartSoundName: try container.decodeIfPresent(String.self, forKey: .eyeBreakStartSoundName) ?? legacySoundName ?? "break-start",
            focusStartSoundName: try container.decodeIfPresent(String.self, forKey: .focusStartSoundName) ?? "focus-complete-soft",
            focusCompleteSoundName: try container.decodeIfPresent(String.self, forKey: .focusCompleteSoundName) ?? "focus-complete",
            breakCompleteSoundName: try container.decodeIfPresent(String.self, forKey: .breakCompleteSoundName) ?? "break-complete",
            soundVolume: try container.decodeIfPresent(Double.self, forKey: .soundVolume) ?? 0.5
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eyeBreakEnabled, forKey: .eyeBreakEnabled)
        try container.encode(eyeBreakIntervalSeconds, forKey: .eyeBreakIntervalSeconds)
        try container.encode(eyeBreakDurationSeconds, forKey: .eyeBreakDurationSeconds)
        try container.encode(snoozeSeconds, forKey: .snoozeSeconds)
        try container.encode(eyeBreakOverlayEnabled, forKey: .eyeBreakOverlayEnabled)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(focusDurationSeconds, forKey: .focusDurationSeconds)
        try container.encode(shortBreakDurationSeconds, forKey: .shortBreakDurationSeconds)
        try container.encode(longBreakDurationSeconds, forKey: .longBreakDurationSeconds)
        try container.encode(longBreakEvery, forKey: .longBreakEvery)
        try container.encode(workHoursEnabled, forKey: .workHoursEnabled)
        try container.encode(workStartMinuteOfDay, forKey: .workStartMinuteOfDay)
        try container.encode(workEndMinuteOfDay, forKey: .workEndMinuteOfDay)
        try container.encode(idleThresholdSeconds, forKey: .idleThresholdSeconds)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(eyeCareFilterEnabled, forKey: .eyeCareFilterEnabled)
        try container.encode(eyeCareFilterStrength, forKey: .eyeCareFilterStrength)
        try container.encode(preReminderEnabled, forKey: .preReminderEnabled)
        try container.encode(preReminderLeadSeconds, forKey: .preReminderLeadSeconds)
        try container.encode(respectSystemFocus, forKey: .respectSystemFocus)
        try container.encode(reduceFullscreenInterruptions, forKey: .reduceFullscreenInterruptions)
        try container.encode(maxSnoozesPerEyeBreak, forKey: .maxSnoozesPerEyeBreak)
        try container.encode(presentationModeDurationSeconds, forKey: .presentationModeDurationSeconds)
        try container.encode(soundEnabled, forKey: .soundEnabled)
        try container.encode(eyeBreakStartSoundName, forKey: .eyeBreakStartSoundName)
        try container.encode(focusStartSoundName, forKey: .focusStartSoundName)
        try container.encode(focusCompleteSoundName, forKey: .focusCompleteSoundName)
        try container.encode(breakCompleteSoundName, forKey: .breakCompleteSoundName)
        try container.encode(soundVolume, forKey: .soundVolume)
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
