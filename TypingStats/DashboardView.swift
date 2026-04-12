import SwiftUI

struct DashboardView: View {
    @ObservedObject var stats: StatsEngine
    @State private var history: [DailyStats] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                heroCards
                funComparison

                HStack(alignment: .top, spacing: 16) {
                    speedSection
                    sessionSection
                }

                activityChart

                HStack(alignment: .top, spacing: 16) {
                    topKeysSection
                    modifiersSection
                }

                if let trend = stats.weeklyTrend {
                    trendSection(trend)
                }

                if !history.isEmpty {
                    historyTable
                }
            }
            .padding(28)
        }
        .frame(minWidth: 640, idealWidth: 720, minHeight: 520, idealHeight: 640)
        .onAppear { history = stats.loadHistory() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Typing Stats")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(todayFormatted)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TypingCharacterView(currentWPM: stats.currentWPM, isTyping: stats.currentWPM > 0)
        }
    }

    // MARK: - Hero Stats

    private var heroCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            HeroCard(value: formatted(stats.todayKeystrokes), label: "Keystrokes",
                     icon: "keyboard", color: .blue)
            HeroCard(value: formatted(stats.todayWords), label: "Words",
                     icon: "text.word.spacing", color: .purple)
            HeroCard(value: "\(stats.averageWPM)", label: "Avg WPM",
                     icon: "gauge.open.with.lines.needle.33percent", color: .orange)
            HeroCard(value: String(format: "%.1f%%", stats.accuracy), label: "Accuracy",
                     icon: "checkmark.circle", color: .green)
        }
    }

    @ViewBuilder
    private var funComparison: some View {
        if stats.todayWords >= 10 {
            Text(stats.funComparison)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Speed

    private var speedSection: some View {
        SectionCard(title: "Speed") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                MetricCell(label: "Current", value: "\(stats.currentWPM)", unit: "WPM")
                MetricCell(label: "Average", value: "\(stats.averageWPM)", unit: "WPM")
                MetricCell(label: "Peak", value: "\(stats.peakWPM)", unit: "WPM")
                MetricCell(label: "Burst (10s)", value: "\(stats.burstWPM)", unit: "WPM")
            }
            if stats.avgInterKeyMs > 0 {
                Divider()
                HStack {
                    Text("Rhythm")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0fms ± %.0fms", stats.avgInterKeyMs, stats.interKeyStdDev))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Sessions

    private var sessionSection: some View {
        SectionCard(title: "Sessions") {
            VStack(spacing: 10) {
                MetricRow(label: "Sessions today", value: "\(stats.sessionCount)")
                MetricRow(label: "Active time", value: stats.activeTimeFormatted)
                MetricRow(label: "Best streak", value: stats.longestStreakFormatted)
                MetricRow(label: "Corrections", value: "\(stats.corrections)")
            }
        }
    }

    // MARK: - Activity Chart

    private var activityChart: some View {
        SectionCard(title: "Today's Activity") {
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<24, id: \.self) { hour in
                        let count = stats.keystrokesPerHour[hour, default: 0]
                        let maxCount = max(stats.keystrokesPerHour.values.max() ?? 1, 1)
                        let ratio = CGFloat(count) / CGFloat(maxCount)

                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(count > 0
                                    ? Color.accentColor.opacity(0.35 + 0.65 * ratio)
                                    : Color.secondary.opacity(0.1))
                                .frame(height: max(4, ratio * 100))

                            if hour % 3 == 0 {
                                Text("\(hour)")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)
            }
        }
    }

    // MARK: - Top Keys

    private var topKeysSection: some View {
        SectionCard(title: "Top Keys") {
            let keys = extendedTopKeys
            if keys.isEmpty {
                Text("Start typing to see key distribution")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 6) {
                    ForEach(keys.indices, id: \.self) { i in
                        let key = keys[i]
                        HStack(spacing: 8) {
                            Text(key.name)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .frame(width: 20, alignment: .trailing)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor.opacity(0.3 + 0.5 * (1 - Double(i) / Double(max(keys.count, 1)))))
                                    .frame(width: geo.size.width * key.percentage / 100)
                            }
                            .frame(height: 14)

                            Text(String(format: "%.1f%%", key.percentage))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Modifiers

    @ViewBuilder
    private var modifiersSection: some View {
        if !stats.modifierCounts.isEmpty {
            SectionCard(title: "Shortcuts") {
                let items: [(key: String, symbol: String)] = [
                    ("shift", "⇧ Shift"), ("cmd", "⌘ Cmd"),
                    ("opt", "⌥ Opt"), ("ctrl", "⌃ Ctrl"),
                ]
                VStack(spacing: 10) {
                    ForEach(items, id: \.key) { item in
                        let count = stats.modifierCounts[item.key, default: 0]
                        HStack {
                            Text(item.symbol)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatted(count))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                    }
                }
            }
        } else {
            SectionCard(title: "Shortcuts") {
                Text("No modifier keys used yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Weekly Trend

    private func trendSection(_ trend: WeeklyTrend) -> some View {
        SectionCard(title: "7-Day Trend") {
            VStack(spacing: 12) {
                HStack {
                    Text("Avg \(trend.avgWPM) WPM")
                        .font(.system(size: 13, weight: .medium))
                    if trend.changePercent != 0 {
                        HStack(spacing: 2) {
                            Text(trend.changePercent > 0 ? "▲" : "▼")
                                .font(.system(size: 10))
                            Text(String(format: "%.0f%%", abs(trend.changePercent)))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(trend.changePercent > 0 ? .green : .red)
                    }
                    Spacer()
                    Text("\(trend.avgWords) words/day")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                // Bar chart for the week
                HStack(alignment: .bottom, spacing: 8) {
                    let maxVal = max(trend.dailyPeakWPMs.max() ?? 1, 1)
                    let dayLabels = weekdayLabels(count: trend.dailyPeakWPMs.count)

                    ForEach(trend.dailyPeakWPMs.indices, id: \.self) { i in
                        let val = trend.dailyPeakWPMs[i]
                        let ratio = CGFloat(val) / CGFloat(maxVal)

                        VStack(spacing: 4) {
                            if val > 0 {
                                Text("\(val)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            RoundedRectangle(cornerRadius: 3)
                                .fill(val > 0 ? Color.accentColor.opacity(0.4 + 0.6 * ratio) : Color.secondary.opacity(0.1))
                                .frame(height: max(4, ratio * 60))
                            Text(dayLabels[i])
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)
            }
        }
    }

    // MARK: - History Table

    private var historyTable: some View {
        SectionCard(title: "Recent History") {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Keys").frame(width: 60, alignment: .trailing)
                    Text("Words").frame(width: 60, alignment: .trailing)
                    Text("Peak").frame(width: 50, alignment: .trailing)
                    Text("Active").frame(width: 60, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

                Divider()

                ForEach(Array(history.suffix(7).reversed().enumerated()), id: \.offset) { _, entry in
                    HStack {
                        Text(formatHistoryDate(entry.date))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(formatted(entry.keystrokes))
                            .frame(width: 60, alignment: .trailing)
                        Text(formatted(entry.words))
                            .frame(width: 60, alignment: .trailing)
                        Text("\(entry.peakWPM)")
                            .frame(width: 50, alignment: .trailing)
                        Text(formatSeconds(entry.activeSeconds))
                            .frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.vertical, 5)

                    Divider()
                }
            }
        }
    }

    // MARK: - Helpers

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: Date())
    }

    private func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatSeconds(_ s: Double) -> String {
        let mins = Int(s) / 60
        let hrs = mins / 60
        let rem = mins % 60
        return hrs > 0 ? "\(hrs)h \(rem)m" : "\(rem)m"
    }

    private func formatHistoryDate(_ dateStr: String) -> String {
        let src = DateFormatter()
        src.dateFormat = "yyyy-MM-dd"
        let dst = DateFormatter()
        dst.dateFormat = "MMM d"
        if let date = src.date(from: dateStr) {
            return dst.string(from: date)
        }
        return dateStr
    }

    private func weekdayLabels(count: Int) -> [String] {
        let cal = Calendar.current
        let today = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return (0..<count).reversed().map { daysBack in
            let date = cal.date(byAdding: .day, value: -daysBack, to: today)!
            return fmt.string(from: date)
        }
    }

    private var extendedTopKeys: [(keyCode: Int, name: String, count: Int, percentage: Double)] {
        let total = stats.keyFrequency.values.reduce(0, +)
        guard total > 0 else { return [] }
        return stats.keyFrequency
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { (keyCode: $0.key,
                     name: StatsEngine.keyCodeNames[$0.key] ?? "?\($0.key)",
                     count: $0.value,
                     percentage: Double($0.value) / Double(total) * 100) }
    }
}

// MARK: - Reusable Components

private struct HeroCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.06))
        )
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

private struct MetricCell: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
    }
}
