import Foundation

enum AppPaths {
    static let bundleIdentifier = "com.snailclimb.EyePomo"

    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("EyePomo", isDirectory: true)
    }

    static var logsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    static var journalsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Journals", isDirectory: true)
    }

    static var stateURL: URL {
        applicationSupportDirectory.appendingPathComponent("state.json")
    }

    static func ensureBaseDirectories() {
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: journalsDirectory, withIntermediateDirectories: true)
    }
}
