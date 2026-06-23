import AppKit
import EyePomoCore
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var panels: [NSPanel] = []

    var visiblePanelCountForDiagnostics: Int {
        panels.filter(\.isVisible).count
    }

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
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.tabbingMode = .disallowed
            panel.animationBehavior = .none
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hidesOnDeactivate = false
            panel.hasShadow = false
            panel.setFrame(screen.frame, display: true)
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
