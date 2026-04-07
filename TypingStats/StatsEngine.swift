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
    private var wordBuffer: String = ""
    private var currentDateString: String = ""
    private var activeTimer: Timer?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
        if let last = lastKeyTime, now.timeIntervalSince(last) <= 5 {
            activeSeconds += now.timeIntervalSince(last)
        }
        lastKeyTime = now

        // Word detection: space (49), return (36), tab (48)
        if keyCode == 49 || keyCode == 36 || keyCode == 48 {
            if !wordBuffer.isEmpty {
                todayWords += 1
                wordBuffer = ""
            }
        } else {
            wordBuffer += "x" // We just need to know something was typed
        }

        // WPM calculation (rolling 60-second window)
        recentKeyTimes.append(now)
        recentKeyTimes = recentKeyTimes.filter { now.timeIntervalSince($0) <= 60 }
        let charsInWindow = recentKeyTimes.count
        // Average word = 5 characters
        let wpm = Int(Double(charsInWindow) / 5.0 * 1.0) // already per minute since window is 60s
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
        // Keep last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let cutoffStr = Self.dateFormatter.string(from: cutoff)
        history = history.filter { $0.date >= cutoffStr }

        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: statsFileURL)
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
        wordBuffer = ""
    }

    private func startActiveTimer() {
        // Decay currentWPM when not typing
        activeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let last = self.lastKeyTime, Date().timeIntervalSince(last) > 5 {
                self.currentWPM = 0
            }
        }
    }
}
