import AppKit
import EyePomoCore
import SwiftUI

@MainActor
final class EyeBreakOverlayWindowController {
    private var panels: [NSPanel] = []

    var visiblePanelCountForDiagnostics: Int {
        panels.filter(\.isVisible).count
    }

    func show(request: OverlayRequest, coordinator: AppCoordinator) {
        guard request.kind == .eyeBreak else {
            return
        }
        dismiss()

        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        for screen in screens {
            let panel = EyeBreakOverlayPanel(
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
            panel.appearance = Appearance.nsAppearance(coordinator.appSettings.appearance)
            panel.setFrame(screen.frame, display: true)

            let hostingView = NSHostingView(
                rootView: EyeBreakOverlayView(coordinator: coordinator, request: request)
            )
            hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView = hostingView
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

    func applyAppearance(_ mode: AppearanceMode) {
        let appearance = Appearance.nsAppearance(mode)
        for panel in panels {
            panel.appearance = appearance
        }
    }
}

private final class EyeBreakOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
