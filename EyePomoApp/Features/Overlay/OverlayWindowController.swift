import AppKit
import EyePomoCore
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var panels: [NSPanel] = []

    func show(request: OverlayRequest, coordinator: AppCoordinator) {
        dismiss()

        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        for screen in screens {
            let panel = OverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hidesOnDeactivate = false
            panel.hasShadow = false
            panel.contentViewController = NSHostingController(
                rootView: OverlayView(coordinator: coordinator, request: request)
            )
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    func dismiss() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
    }
}

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}
