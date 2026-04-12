import SwiftUI
import Combine
import ServiceManagement

@main
struct TypingStatsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(appState)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: appState.isTracking ? "keyboard.fill" : "keyboard")
                if appState.isTracking && appState.stats.currentWPM > 0 {
                    Text("\(appState.stats.currentWPM)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Toggle
            HStack {
                Toggle(isOn: $appState.isTracking) {
                    Label("Track Typing", systemImage: "keyboard")
                        .font(.system(size: 13, weight: .medium))
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            HStack {
                Toggle(isOn: $appState.showCharacter) {
                    Label("Desktop Buddy", systemImage: "figure.wave")
                        .font(.system(size: 13, weight: .medium))
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            HStack {
                Toggle(isOn: $appState.launchAtLogin) {
                    Label("Launch at Login", systemImage: "sunrise")
                        .font(.system(size: 13, weight: .medium))
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if !appState.hasAccessibility {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 11))
                    Text("Accessibility permission required")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            Divider()

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Today").tag(0)
                Text("Deep").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if selectedTab == 0 {
                SummaryView(
                    keystrokes: appState.stats.todayKeystrokes,
                    words: appState.stats.todayWords,
                    peakWPM: appState.stats.peakWPM,
                    activeTime: appState.stats.activeTimeFormatted,
                    comparison: appState.stats.funComparison,
                    currentWPM: appState.stats.currentWPM,
                    isTyping: appState.stats.currentWPM > 0,
                    keystrokesPerHour: appState.stats.keystrokesPerHour
                )
            } else {
                AnalyticsView(stats: appState.stats)
            }

            Divider()

            // Dashboard button
            Button(action: appState.showDashboard) {
                HStack {
                    Label("Open Dashboard", systemImage: "macwindow")
                        .font(.system(size: 12))
                    Spacer()
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Share & Export
            HStack {
                Button(action: appState.shareCard) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: appState.exportStats) {
                    Label("Export", systemImage: "arrow.down.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            Button(action: {
                appState.stats.saveToDisk()
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Text("Quit Typing Stats")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\u{2318}Q")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 260)
    }
}

class AppState: ObservableObject {
    private var didFinishInit = false

    @Published var isTracking: Bool = true {
        didSet {
            guard didFinishInit else { return }
            UserDefaults.standard.set(isTracking, forKey: "isTracking")
            isTracking ? monitor.start() : monitor.stop()
        }
    }
    @Published var showCharacter: Bool = true {
        didSet {
            guard didFinishInit else { return }
            UserDefaults.standard.set(showCharacter, forKey: "showCharacter")
            showCharacter ? floatingWindow.show() : floatingWindow.hide()
        }
    }
    @Published var launchAtLogin: Bool = false {
        didSet {
            guard didFinishInit else { return }
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
    @Published var hasAccessibility: Bool = false
    @Published var stats = StatsEngine()

    private let monitor = KeyboardMonitor()
    private lazy var floatingWindow: FloatingCharacterWindow = {
        let w = FloatingCharacterWindow(stats: stats)
        w.onHide = { [weak self] in self?.showCharacter = false }
        w.onOpenDashboard = { [weak self] in self?.showDashboard() }
        return w
    }()
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var dashboardWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    init() {
        self.isTracking = UserDefaults.standard.object(forKey: "isTracking") as? Bool ?? true
        self.showCharacter = UserDefaults.standard.object(forKey: "showCharacter") as? Bool ?? true
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        checkAccessibility()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkAccessibility()
        }

        monitor.onKeyDown = { [weak self] keyCode, flags in
            self?.stats.recordKeystroke(keyCode: keyCode, modifierFlags: flags)
            self?.objectWillChange.send()
        }

        // Forward stats changes
        stats.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        didFinishInit = true

        if isTracking {
            monitor.start()
        }

        // Show floating character after a short delay (window server needs time)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.showCharacter else { return }
            self.floatingWindow.show()
        }

        // Show onboarding on first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    private func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        if trusted != hasAccessibility {
            hasAccessibility = trusted
            // Permission just granted — start the monitor
            if trusted && isTracking {
                monitor.start()
            }
        }
        if !trusted && isTracking {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }

    @MainActor
    func shareCard() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateStr = dateFormatter.string(from: Date())

        let card = ShareableCard(
            keystrokes: stats.todayKeystrokes,
            words: stats.todayWords,
            peakWPM: stats.peakWPM,
            activeTime: stats.activeTimeFormatted,
            comparison: stats.funComparison,
            date: dateStr
        )

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0

        guard let image = renderer.nsImage else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        // Also show save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "typing-stats-\(Self.fileDateFormatter.string(from: Date())).png"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let png = bitmap.representation(using: .png, properties: [:]) {
                    try? png.write(to: url)
                }
            }
        }
    }

    @MainActor
    func exportStats() {
        stats.saveToDisk()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "typing-stats-\(Self.fileDateFormatter.string(from: Date())).json"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            let history = self.stats.loadHistory()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            do {
                let data = try encoder.encode(history)
                try data.write(to: url)
            } catch {
                print("Failed to export stats: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Windows

    @MainActor
    func showDashboard() {
        if let existing = dashboardWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = DashboardView(stats: stats)
        let hosting = NSHostingView(rootView: content)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Typing Stats"
        window.titlebarAppearsTransparent = true
        window.contentView = hosting
        window.center()
        window.setFrameAutosaveName("DashboardWindow")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Clean up reference when window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.dashboardWindow = nil
        }

        self.dashboardWindow = window
    }

    @MainActor
    private func showOnboarding() {
        if onboardingWindow != nil { return }

        let content = OnboardingView(hasAccessibility: Binding(
            get: { [weak self] in self?.hasAccessibility ?? false },
            set: { _ in }
        )) { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }

        let hosting = NSHostingView(rootView: content)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Typing Stats"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentView = hosting
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.onboardingWindow = window
    }

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
