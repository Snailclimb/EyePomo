import CoreGraphics
import EyePomoCore
import Foundation

@MainActor
final class IdleMonitor {
    private let threshold: () -> Int
    private let handler: (PresenceEvent) -> Void
    private var timer: Timer?
    private var isIdle = false
    private var lastIdleSeconds = 0

    init(threshold: @escaping () -> Int, handler: @escaping (PresenceEvent) -> Void) {
        self.threshold = threshold
        self.handler = handler
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let idleSeconds = Int(CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved))
        lastIdleSeconds = max(lastIdleSeconds, idleSeconds)

        if idleSeconds >= threshold(), !isIdle {
            isIdle = true
            handler(.idleThresholdReached(idleSeconds: idleSeconds))
        } else if idleSeconds < 3, isIdle {
            isIdle = false
            handler(.userReturned(idleSeconds: lastIdleSeconds))
            lastIdleSeconds = 0
        }
    }
}
