import Foundation

struct AppPaths: Sendable, Equatable {
    static let bundleIdentifier = "com.snailclimb.EyePomo"

    static var defaultApplicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("EyePomo", isDirectory: true)
    }

    var applicationSupportDirectory: URL

    init(applicationSupportDirectory: URL = Self.defaultApplicationSupportDirectory) {
        self.applicationSupportDirectory = applicationSupportDirectory.standardizedFileURL
    }

    var logsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    var journalsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Journals", isDirectory: true)
    }

    var summariesDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Summaries", isDirectory: true)
    }

    var stateURL: URL {
        applicationSupportDirectory.appendingPathComponent("state.json")
    }

    func ensureBaseDirectories() throws {
        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: journalsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: summariesDirectory, withIntermediateDirectories: true)
    }
}
