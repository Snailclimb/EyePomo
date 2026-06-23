import EyePomoCore
import Foundation

struct AppStateStore {
    private struct Snapshot: Codable {
        var savedAt: Date
        var uptimeMilliseconds: Int64
        var state: AppState
    }

    func load(now: AppInstant, wallDate: Date) -> AppState? {
        guard let data = try? Data(contentsOf: AppPaths.stateURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return nil
        }

        let elapsed = max(0, Int(wallDate.timeIntervalSince(snapshot.savedAt)))
        let savedInstant = AppInstant(milliseconds: snapshot.uptimeMilliseconds)
        var state = snapshot.state

        if state.pomodoro.runState == .running, let deadline = state.pomodoro.deadline {
            let remaining = max(0, deadline.remainingSeconds(at: savedInstant) - elapsed)
            state.pomodoro.deadline = remaining > 0 ? Deadline(startedAt: now, durationSeconds: remaining) : Deadline(startedAt: now, durationSeconds: 0)
        }

        if let nextDueAt = state.eyeBreak.nextDueAt {
            let remaining = max(0, savedInstant.seconds(until: nextDueAt) - elapsed)
            state.eyeBreak.nextDueAt = now.adding(seconds: remaining)
        }

        if state.eyeBreak.phase == .active {
            state.eyeBreak.phase = .scheduled
            state.eyeBreak.activeDeadline = nil
            state.eyeBreak.nextDueAt = now.adding(seconds: state.preferences.eyeBreakIntervalSeconds)
            state.presentation.activeOverlay = nil
        }

        return state
    }

    func save(_ state: AppState, now: AppInstant, wallDate: Date) {
        AppPaths.ensureBaseDirectories()
        let snapshot = Snapshot(savedAt: wallDate, uptimeMilliseconds: now.milliseconds, state: state)
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        try? data.write(to: AppPaths.stateURL, options: .atomic)
    }
}
