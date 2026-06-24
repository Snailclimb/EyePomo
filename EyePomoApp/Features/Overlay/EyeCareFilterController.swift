import AppKit

/// 持久的「护眼模式」屏幕滤镜：在每块屏幕上覆盖一层暖色半透明面板，
/// 降低蓝光（类似 Night Shift / f.lux）。`ignoresMouseEvents = true` 使鼠标点击穿透，
/// 用户照常操作。强度变化时刷新 `backgroundColor`，屏幕增减时整体重建。
@MainActor
final class EyeCareFilterController {
    private var panels: [NSPanel] = []
    private var panelCount: Int = 0

    var visiblePanelCountForDiagnostics: Int {
        panels.filter(\.isVisible).count
    }

    func update(enabled: Bool, strength: Double) {
        if enabled {
            showOrUpdate(strength: strength)
        } else {
            hide()
        }
    }

    func hide() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
        panelCount = 0
    }

    private func showOrUpdate(strength: Double) {
        let clamped = max(0.05, min(0.50, strength))
        let color = Self.filterColor(strength: clamped)
        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens

        if screens.count != panelCount {
            hide()
            for screen in screens {
                let panel = EyeCareFilterPanel(
                    contentRect: screen.frame,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.level = .floating
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                panel.isFloatingPanel = false
                panel.becomesKeyOnlyIfNeeded = true
                panel.tabbingMode = .disallowed
                panel.animationBehavior = .none
                panel.backgroundColor = color
                panel.isOpaque = false
                panel.hidesOnDeactivate = false
                panel.hasShadow = false
                panel.ignoresMouseEvents = true
                panel.setFrame(screen.frame, display: true)
                panel.orderFrontRegardless()
                panels.append(panel)
            }
            panelCount = screens.count
        } else {
            for panel in panels {
                panel.backgroundColor = color
            }
        }
    }

    /// 琥珀橙：降蓝光。alpha 即滤镜强度。
    static func filterColor(strength: Double) -> NSColor {
        NSColor(srgbRed: 1.0, green: 0.62, blue: 0.28, alpha: strength)
    }
}

private final class EyeCareFilterPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
