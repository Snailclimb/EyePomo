import AppKit
import Foundation

enum AppSoundCatalog {
    static let breakStartDefault = "break-start"
    static let focusStartDefault = "focus-complete-soft"
    static let focusCompleteDefault = "focus-complete"
    static let breakCompleteDefault = "break-complete"

    static let breakStartNames = [
        "break-start",
        "break-start-soft",
        "break-start-open"
    ]

    static let focusCompleteNames = [
        "focus-complete",
        "focus-complete-bright",
        "focus-complete-soft"
    ]

    static let focusStartNames = [
        "focus-complete-soft",
        "focus-complete",
        "focus-complete-bright"
    ]

    static let breakCompleteNames = [
        "break-complete",
        "break-complete-crisp",
        "break-complete-soft"
    ]

    static let availableNames = breakStartNames + focusCompleteNames + breakCompleteNames

    static func normalizedBreakStartName(_ name: String) -> String {
        breakStartNames.contains(name) ? name : breakStartDefault
    }

    static func normalizedFocusStartName(_ name: String) -> String {
        focusStartNames.contains(name) ? name : focusStartDefault
    }

    static func normalizedFocusCompleteName(_ name: String) -> String {
        focusCompleteNames.contains(name) ? name : focusCompleteDefault
    }

    static func normalizedBreakCompleteName(_ name: String) -> String {
        breakCompleteNames.contains(name) ? name : breakCompleteDefault
    }

    static func normalizedName(_ name: String, fallback: String) -> String {
        availableNames.contains(name) ? name : fallback
    }

    static func localizedOptionTitle(for name: String, english: Bool) -> String {
        switch name {
        case "break-start", "focus-complete", "break-complete":
            return english ? "Default" : "默认"
        case "break-start-soft", "focus-complete-soft", "break-complete-soft":
            return english ? "Soft" : "柔和"
        case "break-start-open":
            return english ? "Light" : "轻快"
        case "focus-complete-bright":
            return english ? "Bright" : "明亮"
        case "break-complete-crisp":
            return english ? "Crisp" : "清脆"
        default:
            return name
        }
    }

    static func localizedTitle(for name: String, english: Bool) -> String {
        switch name {
        case "break-start":
            return english ? "Break start" : "休息开始"
        case "break-start-soft":
            return english ? "Break start soft" : "休息开始 柔和"
        case "break-start-open":
            return english ? "Break start light" : "休息开始 轻快"
        case "focus-complete":
            return english ? "Focus complete" : "专注完成"
        case "focus-complete-bright":
            return english ? "Focus complete bright" : "专注完成 明亮"
        case "focus-complete-soft":
            return english ? "Focus complete soft" : "专注完成 柔和"
        case "break-complete":
            return english ? "Break complete" : "休息完成"
        case "break-complete-crisp":
            return english ? "Break complete crisp" : "休息完成 清脆"
        case "break-complete-soft":
            return english ? "Break complete soft" : "休息完成 柔和"
        default:
            return name
        }
    }
}

@MainActor
final class SoundPlayer {
    private var activeSounds: [NSSound] = []

    func play(name: String, volume: Double) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf"),
              let sound = NSSound(contentsOf: url, byReference: true)
        else {
            return
        }

        sound.volume = Float(min(1, max(0, volume)))
        activeSounds.append(sound)
        sound.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.activeSounds.removeAll { !$0.isPlaying }
        }
    }
}
