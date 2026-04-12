import Foundation
import CoreGraphics

struct DailyStats: Codable {
    var date: String // yyyy-MM-dd
    var keystrokes: Int
    var words: Int
    var peakWPM: Int
    var activeSeconds: Double
    var keystrokesPerHour: [Int: Int] // hour (0-23) -> count
    // Analytics (optional for backward compatibility with existing data)
    var corrections: Int?
    var burstWPM: Int?
    var avgInterKeyMs: Double?
    var interKeyStdDev: Double?
    var keyFrequency: [Int: Int]?
    var sessionCount: Int?
    var longestStreakSeconds: Double?
    var modifierCounts: [String: Int]?
}

struct WeeklyTrend {
    let avgWPM: Int
    let avgWords: Int
    let avgActiveMinutes: Int
    let changePercent: Double
    let dailyPeakWPMs: [Int] // last 7 days, chronological order
}

class StatsEngine: ObservableObject {
    // MARK: - Core Stats
    @Published var todayKeystrokes: Int = 0
    @Published var todayWords: Int = 0
    @Published var currentWPM: Int = 0
    @Published var peakWPM: Int = 0
    @Published var activeSeconds: Double = 0
    @Published var keystrokesPerHour: [Int: Int] = [:]

    // MARK: - Analytics
    @Published var corrections: Int = 0
    @Published var burstWPM: Int = 0
    @Published var keyFrequency: [Int: Int] = [:]
    @Published var sessionCount: Int = 0
    @Published var longestStreakSeconds: Double = 0
    @Published var modifierCounts: [String: Int] = [:]  // "shift", "cmd", "opt", "ctrl"
    @Published private(set) var weeklyTrend: WeeklyTrend? = nil

    // MARK: - Private State
    private var recentKeyTimes: [Date] = []
    private var lastKeyTime: Date?
    private var hasPartialWord: Bool = false
    private var currentDateString: String = ""
    private var activeTimer: Timer?

    // Welford's online algorithm for inter-key interval statistics
    private var interKeyCount: Int = 0
    private var interKeyMean: Double = 0
    private var interKeyM2: Double = 0

    // 10-second burst window
    private var burstKeyTimes: [Date] = []

    // Streak tracking (continuous typing without >3s gap)
    private var currentStreakStart: Date?

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

    static let keyCodeNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "⏎", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "⇥", 49: "␣", 50: "`", 51: "⌫",
    ]

    init() {
        currentDateString = Self.dateFormatter.string(from: Date())
        loadToday()
        startActiveTimer()
    }

    // MARK: - Keystroke Recording

    func recordKeystroke(keyCode: Int64, modifierFlags: CGEventFlags = []) {
        let now = Date()
        let todayStr = Self.dateFormatter.string(from: now)

        // Day rollover
        if todayStr != currentDateString {
            saveToDisk()
            resetForNewDay()
            currentDateString = todayStr
        }

        todayKeystrokes += 1

        let hour = Calendar.current.component(.hour, from: now)
        keystrokesPerHour[hour, default: 0] += 1

        // Corrections (backspace = keyCode 51, forward delete = 117)
        if keyCode == 51 || keyCode == 117 {
            corrections += 1
        }

        // Key frequency
        keyFrequency[Int(keyCode), default: 0] += 1

        // Modifier tracking
        if modifierFlags.contains(.maskShift) { modifierCounts["shift", default: 0] += 1 }
        if modifierFlags.contains(.maskCommand) { modifierCounts["cmd", default: 0] += 1 }
        if modifierFlags.contains(.maskAlternate) { modifierCounts["opt", default: 0] += 1 }
        if modifierFlags.contains(.maskControl) { modifierCounts["ctrl", default: 0] += 1 }

        let isCharKey = !Self.nonCharacterKeyCodes.contains(keyCode)

        // Active time, rhythm, sessions, streaks
        if let last = lastKeyTime {
            let delta = now.timeIntervalSince(last)

            // Active typing time (within 5s of last key)
            if delta > 0 && delta <= 5 {
                activeSeconds += delta
            }

            // Inter-key interval stats via Welford's algorithm (only during active typing ≤2s)
            if delta > 0 && delta <= 2 {
                interKeyCount += 1
                let d1 = delta - interKeyMean
                interKeyMean += d1 / Double(interKeyCount)
                let d2 = delta - interKeyMean
                interKeyM2 += d1 * d2
            }

            // Session detection (gap >60s = new session)
            if delta > 60 {
                sessionCount += 1
            }

            // Streak tracking (gap >3s breaks the streak)
            if delta > 3 {
                if let start = currentStreakStart {
                    let streakDuration = last.timeIntervalSince(start)
                    if streakDuration > longestStreakSeconds {
                        longestStreakSeconds = streakDuration
                    }
                }
                currentStreakStart = now
            }
        } else {
            // First keystroke of the day
            sessionCount = 1
            currentStreakStart = now
        }
        lastKeyTime = now

        // Update longest streak with ongoing streak
        if let start = currentStreakStart {
            let current = now.timeIntervalSince(start)
            if current > longestStreakSeconds {
                longestStreakSeconds = current
            }
        }

        // Word detection: space (49), return (36), tab (48)
        if keyCode == 49 || keyCode == 36 || keyCode == 48 {
            if hasPartialWord {
                todayWords += 1
                hasPartialWord = false
            }
        } else if isCharKey {
            hasPartialWord = true
        }

        // WPM (rolling 60-second window, character keys only)
        if isCharKey {
            recentKeyTimes.append(now)
        }
        recentKeyTimes = recentKeyTimes.filter { now.timeIntervalSince($0) <= 60 }
        let wpm = Int(Double(recentKeyTimes.count) / 5.0) // 60s window, avg word = 5 chars
        currentWPM = wpm
        if wpm > peakWPM {
            peakWPM = wpm
        }

        // Burst WPM (10-second window, character keys only)
        if isCharKey {
            burstKeyTimes.append(now)
        }
        burstKeyTimes = burstKeyTimes.filter { now.timeIntervalSince($0) <= 10 }
        let currentBurst = Int(Double(burstKeyTimes.count) / 5.0 * 6.0) // scale 10s → 60s
        if currentBurst > burstWPM {
            burstWPM = currentBurst
        }

        // Auto-save every 100 keystrokes
        if todayKeystrokes % 100 == 0 {
            saveToDisk()
        }
    }

    // MARK: - Computed Analytics

    var correctionRate: Double {
        guard todayKeystrokes > 0 else { return 0 }
        return Double(corrections) / Double(todayKeystrokes) * 100
    }

    var accuracy: Double {
        max(0, 100 - correctionRate)
    }

    var avgInterKeyMs: Double {
        guard interKeyCount > 0 else { return 0 }
        return interKeyMean * 1000
    }

    var interKeyStdDev: Double {
        guard interKeyCount > 1 else { return 0 }
        return sqrt(interKeyM2 / Double(interKeyCount)) * 1000
    }

    var averageWPM: Int {
        guard activeSeconds >= 10 else { return 0 }
        return Int((Double(todayKeystrokes) / 5.0) / (activeSeconds / 60.0))
    }

    var longestStreakFormatted: String {
        let total = Int(longestStreakSeconds)
        let m = total / 60
        let s = total % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    var topKeys: [(keyCode: Int, name: String, count: Int, percentage: Double)] {
        let total = keyFrequency.values.reduce(0, +)
        guard total > 0 else { return [] }
        return keyFrequency
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (keyCode: $0.key,
                     name: Self.keyCodeNames[$0.key] ?? "?\($0.key)",
                     count: $0.value,
                     percentage: Double($0.value) / Double(total) * 100) }
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
        return hrs > 0 ? "\(hrs)h \(remainingMins)m" : "\(remainingMins)m"
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
            keystrokesPerHour: keystrokesPerHour,
            corrections: corrections,
            burstWPM: burstWPM,
            avgInterKeyMs: avgInterKeyMs > 0 ? avgInterKeyMs : nil,
            interKeyStdDev: interKeyStdDev > 0 ? interKeyStdDev : nil,
            keyFrequency: keyFrequency.isEmpty ? nil : keyFrequency,
            sessionCount: sessionCount > 0 ? sessionCount : nil,
            longestStreakSeconds: longestStreakSeconds > 0 ? longestStreakSeconds : nil,
            modifierCounts: modifierCounts.isEmpty ? nil : modifierCounts
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
            corrections = today.corrections ?? 0
            burstWPM = today.burstWPM ?? 0
            keyFrequency = today.keyFrequency ?? [:]
            sessionCount = today.sessionCount ?? 0
            longestStreakSeconds = today.longestStreakSeconds ?? 0
            modifierCounts = today.modifierCounts ?? [:]
        }
        weeklyTrend = computeWeeklyTrend(from: history)
    }

    private func resetForNewDay() {
        todayKeystrokes = 0
        todayWords = 0
        currentWPM = 0
        peakWPM = 0
        activeSeconds = 0
        keystrokesPerHour = [:]
        corrections = 0
        burstWPM = 0
        keyFrequency = [:]
        sessionCount = 0
        longestStreakSeconds = 0
        modifierCounts = [:]
        recentKeyTimes = []
        lastKeyTime = nil
        hasPartialWord = false
        interKeyCount = 0
        interKeyMean = 0
        interKeyM2 = 0
        burstKeyTimes = []
        currentStreakStart = nil
        weeklyTrend = computeWeeklyTrend(from: loadHistory())
    }

    // MARK: - Weekly Trend

    private func computeWeeklyTrend(from history: [DailyStats]) -> WeeklyTrend? {
        guard history.count >= 2 else { return nil }

        let calendar = Calendar.current
        let today = Date()

        func daysAgo(_ entry: DailyStats) -> Int? {
            guard let date = Self.dateFormatter.date(from: entry.date) else { return nil }
            return calendar.dateComponents([.day], from: date, to: today).day
        }

        func avgWPMFor(_ entry: DailyStats) -> Int {
            guard entry.activeSeconds > 30 else { return 0 }
            return Int((Double(entry.keystrokes) / 5.0) / (entry.activeSeconds / 60.0))
        }

        let last7 = history.filter {
            guard let d = daysAgo($0) else { return false }
            return d >= 0 && d < 7
        }
        let prev7 = history.filter {
            guard let d = daysAgo($0) else { return false }
            return d >= 7 && d < 14
        }

        guard !last7.isEmpty else { return nil }

        let wpms = last7.map { avgWPMFor($0) }.filter { $0 > 0 }
        let avgWPM = wpms.isEmpty ? 0 : wpms.reduce(0, +) / wpms.count
        let avgWords = last7.map { $0.words }.reduce(0, +) / last7.count
        let avgActiveMins = Int(last7.map { $0.activeSeconds }.reduce(0, +) / Double(last7.count) / 60)

        var change = 0.0
        if !prev7.isEmpty {
            let prevWPMs = prev7.map { avgWPMFor($0) }.filter { $0 > 0 }
            let prevAvg = prevWPMs.isEmpty ? 0 : prevWPMs.reduce(0, +) / prevWPMs.count
            if prevAvg > 0 {
                change = Double(avgWPM - prevAvg) / Double(prevAvg) * 100
            }
        }

        let dailyPeakWPMs: [Int] = (0..<7).reversed().map { daysBack in
            let date = calendar.date(byAdding: .day, value: -daysBack, to: today)!
            let dateStr = Self.dateFormatter.string(from: date)
            return history.first { $0.date == dateStr }?.peakWPM ?? 0
        }

        return WeeklyTrend(
            avgWPM: avgWPM,
            avgWords: avgWords,
            avgActiveMinutes: avgActiveMins,
            changePercent: change,
            dailyPeakWPMs: dailyPeakWPMs
        )
    }

    // MARK: - Timer

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
