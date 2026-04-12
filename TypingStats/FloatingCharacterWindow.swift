import SwiftUI
import AppKit

class FloatingCharacterWindow {
    private var panel: NSPanel?
    private var stats: StatsEngine
    private var moveObserver: NSObjectProtocol?
    var onHide: (() -> Void)?
    var onOpenDashboard: (() -> Void)?

    private static let positionKey = "buddyWindowPosition"

    init(stats: StatsEngine) {
        self.stats = stats
    }

    func show() {
        guard panel == nil else { return }

        let content = DesktopCharacterView(
            stats: stats,
            onHide: { [weak self] in self?.onHide?() },
            onOpenDashboard: { [weak self] in self?.onOpenDashboard?() }
        )

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

        // Restore saved position or default to bottom-right
        restorePosition(panel)

        // Save position when dragged
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.savePosition()
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        savePosition()
        if let observer = moveObserver {
            NotificationCenter.default.removeObserver(observer)
            moveObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool {
        panel != nil
    }

    // MARK: - Position Persistence

    private func savePosition() {
        guard let origin = panel?.frame.origin else { return }
        UserDefaults.standard.set(
            NSStringFromPoint(origin),
            forKey: Self.positionKey
        )
    }

    private func restorePosition(_ panel: NSPanel) {
        if let saved = UserDefaults.standard.string(forKey: Self.positionKey) {
            let point = NSPointFromString(saved)
            // Validate the saved position is still on a connected screen
            if isPointOnScreen(point, windowSize: panel.frame.size) {
                panel.setFrameOrigin(point)
                return
            }
        }
        positionBottomRight(panel)
    }

    private func positionBottomRight(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - 160 - 16
        let y = screenFrame.minY + 16
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func isPointOnScreen(_ point: NSPoint, windowSize: NSSize) -> Bool {
        let windowRect = NSRect(origin: point, size: windowSize)
        return NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(windowRect)
        }
    }
}
