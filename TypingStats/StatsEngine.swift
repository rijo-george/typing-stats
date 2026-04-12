import Foundation

struct DailyStats: Codable {
    var date: String // yyyy-MM-dd
    var keystrokes: Int
    var words: Int
    var peakWPM: Int
    var activeSeconds: Double
    var keystrokesPerHour: [Int: Int] // hour (0-23) -> count
}

class StatsEngine: ObservableObject {
    @Published var todayKeystrokes: Int = 0
    @Published var todayWords: Int = 0
    @Published var currentWPM: Int = 0
    @Published var peakWPM: Int = 0
    @Published var activeSeconds: Double = 0
    @Published var keystrokesPerHour: [Int: Int] = [:]

    private var recentKeyTimes: [Date] = []
    private var lastKeyTime: Date?
    private var hasPartialWord: Bool = false
    private var currentDateString: String = ""
    private var activeTimer: Timer?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // Keys that don't produce characters — excluded from WPM calculation
    private static let nonCharacterKeyCodes: Set<Int64> = [
        53,                                     // Escape
        115, 119, 116, 121,                     // Home, End, Page Up, Page Down
        117,                                    // Forward Delete
        114,                                    // Help/Insert
        123, 124, 125, 126,                     // Arrow keys
        122, 120, 99, 118, 96, 97, 98, 100,    // F1–F8
        101, 109, 103, 111, 105, 107, 113,      // F9–F15
        106, 64, 79, 80, 90,                    // F16–F20
    ]

    init() {
        currentDateString = Self.dateFormatter.string(from: Date())
        loadToday()
        startActiveTimer()
    }

    func recordKeystroke(keyCode: Int64) {
        let now = Date()
        let todayStr = Self.dateFormatter.string(from: now)

        // Day rollover
        if todayStr != currentDateString {
            saveToDisk()
            resetForNewDay()
            currentDateString = todayStr
        }

        todayKeystrokes += 1

        // Track per-hour
        let hour = Calendar.current.component(.hour, from: now)
        keystrokesPerHour[hour, default: 0] += 1

        // Track active typing time (count if last key was within 5 seconds)
        if let last = lastKeyTime {
            let delta = now.timeIntervalSince(last)
            if delta > 0 && delta <= 5 {
                activeSeconds += delta
            }
        }
        lastKeyTime = now

        // Word detection: space (49), return (36), tab (48)
        if keyCode == 49 || keyCode == 36 || keyCode == 48 {
            if hasPartialWord {
                todayWords += 1
                hasPartialWord = false
            }
        } else if !Self.nonCharacterKeyCodes.contains(keyCode) {
            hasPartialWord = true
        }

        // WPM calculation (rolling 60-second window, character keys only)
        if !Self.nonCharacterKeyCodes.contains(keyCode) {
            recentKeyTimes.append(now)
        }
        recentKeyTimes = recentKeyTimes.filter { now.timeIntervalSince($0) <= 60 }
        let wpm = Int(Double(recentKeyTimes.count) / 5.0) // 60s window, avg word = 5 chars
        currentWPM = wpm
        if wpm > peakWPM {
            peakWPM = wpm
        }

        // Auto-save every 100 keystrokes
        if todayKeystrokes % 100 == 0 {
            saveToDisk()
        }
    }

    // MARK: - Fun Comparisons

    var novelPages: Double {
        Double(todayWords) / 250.0
    }

    var funComparison: String {
        let w = todayWords
        if w < 10 { return "Just warming up..." }
        if w < 100 { return "That's a solid paragraph." }
        if w < 500 { return "That's a full page of a novel." }
        if w < 1000 { return "That's a short blog post." }
        if w < 2500 { return "That's about \(Int(novelPages)) pages of a novel." }
        if w < 5000 { return "That's a college essay worth of words." }
        if w < 10000 { return "That's \(Int(novelPages)) pages \u{2014} a short story!" }
        if w < 20000 { return "That's \(Int(novelPages)) pages. You could write a novella at this pace!" }
        return "That's \(Int(novelPages)) pages \u{2014} absolutely prolific!"
    }

    var activeTimeFormatted: String {
        let mins = Int(activeSeconds) / 60
        let hrs = mins / 60
        let remainingMins = mins % 60
        if hrs > 0 {
            return "\(hrs)h \(remainingMins)m"
        }
        return "\(remainingMins)m"
    }

    // MARK: - Persistence

    private var statsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("TypingStats")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    func saveToDisk() {
        var history = loadHistory()
        let today = DailyStats(
            date: currentDateString,
            keystrokes: todayKeystrokes,
            words: todayWords,
            peakWPM: peakWPM,
            activeSeconds: activeSeconds,
            keystrokesPerHour: keystrokesPerHour
        )
        if let idx = history.firstIndex(where: { $0.date == currentDateString }) {
            history[idx] = today
        } else {
            history.append(today)
        }
        // Keep last 90 days (yyyy-MM-dd format sorts lexicographically == chronologically)
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let cutoffStr = Self.dateFormatter.string(from: cutoff)
        history = history.filter { $0.date >= cutoffStr }

        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: statsFileURL)
        } catch {
            print("Failed to save typing stats: \(error.localizedDescription)")
        }
    }

    func loadHistory() -> [DailyStats] {
        guard let data = try? Data(contentsOf: statsFileURL),
              let history = try? JSONDecoder().decode([DailyStats].self, from: data) else {
            return []
        }
        return history
    }

    private func loadToday() {
        let history = loadHistory()
        if let today = history.first(where: { $0.date == currentDateString }) {
            todayKeystrokes = today.keystrokes
            todayWords = today.words
            peakWPM = today.peakWPM
            activeSeconds = today.activeSeconds
            keystrokesPerHour = today.keystrokesPerHour
        }
    }

    private func resetForNewDay() {
        todayKeystrokes = 0
        todayWords = 0
        currentWPM = 0
        peakWPM = 0
        activeSeconds = 0
        keystrokesPerHour = [:]
        recentKeyTimes = []
        lastKeyTime = nil
        hasPartialWord = false
    }

    private func startActiveTimer() {
        // Decay currentWPM when not typing.
        // Timer is scheduled on the main run loop (init runs on main thread),
        // so the callback executes on the main thread alongside recordKeystroke.
        activeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let last = self.lastKeyTime, Date().timeIntervalSince(last) > 5 {
                self.currentWPM = 0
            }
        }
    }
}
