import SwiftUI
import Combine

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

            // Summary card
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

            Divider()

            // Share & Quit
            HStack {
                Button(action: appState.shareCard) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: { appState.stats.saveToDisk() }) {
                    Label("Save", systemImage: "arrow.down.doc")
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
    @Published var isTracking: Bool {
        didSet {
            UserDefaults.standard.set(isTracking, forKey: "isTracking")
            isTracking ? monitor.start() : monitor.stop()
        }
    }
    @Published var showCharacter: Bool {
        didSet {
            UserDefaults.standard.set(showCharacter, forKey: "showCharacter")
            showCharacter ? floatingWindow.show() : floatingWindow.hide()
        }
    }
    @Published var hasAccessibility: Bool = false
    @Published var stats = StatsEngine()

    private let monitor = KeyboardMonitor()
    private lazy var floatingWindow = FloatingCharacterWindow(stats: stats)
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let saved = UserDefaults.standard.object(forKey: "isTracking") as? Bool ?? true
        self.isTracking = saved
        self.showCharacter = UserDefaults.standard.object(forKey: "showCharacter") as? Bool ?? true

        checkAccessibility()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkAccessibility()
        }

        monitor.onKeyDown = { [weak self] keyCode in
            self?.stats.recordKeystroke(keyCode: keyCode)
            self?.objectWillChange.send()
        }

        // Forward stats changes
        stats.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        if isTracking {
            monitor.start()
        }

        // Show floating character after a short delay (window server needs time)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.showCharacter else { return }
            self.floatingWindow.show()
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

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
