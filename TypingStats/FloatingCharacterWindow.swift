import SwiftUI
import AppKit

class FloatingCharacterWindow {
    private var panel: NSPanel?
    private var stats: StatsEngine

    init(stats: StatsEngine) {
        self.stats = stats
    }

    func show() {
        guard panel == nil else { return }

        let content = DesktopCharacterView(stats: stats)

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 160, height: 160)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
        panel.ignoresMouseEvents = false

        // Position: bottom-right of main screen
        positionBottomRight(panel)

        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool {
        panel != nil
    }

    private func positionBottomRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - 160 - 16
        let y = screenFrame.minY + 16
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
