import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var stats: StatsEngine

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Analytics")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Metrics
            VStack(spacing: 6) {
                AnalyticRow(
                    label: "Accuracy",
                    value: String(format: "%.1f%%", stats.accuracy),
                    detail: "\(stats.corrections) corrections"
                )
                AnalyticRow(
                    label: "Avg WPM",
                    value: "\(stats.averageWPM)",
                    detail: stats.averageWPM > 0 ? "while active" : nil
                )
                AnalyticRow(
                    label: "Burst",
                    value: "\(stats.burstWPM) WPM",
                    detail: "10s peak"
                )
                if stats.avgInterKeyMs > 0 {
                    AnalyticRow(
                        label: "Rhythm",
                        value: String(format: "%.0fms", stats.avgInterKeyMs),
                        detail: String(format: "± %.0fms", stats.interKeyStdDev)
                    )
                }
                AnalyticRow(label: "Sessions", value: "\(stats.sessionCount)")
                if stats.longestStreakSeconds > 0 {
                    AnalyticRow(label: "Best Streak", value: stats.longestStreakFormatted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            // Modifiers
            if !stats.modifierCounts.isEmpty {
                HStack {
                    Text("Shortcuts")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                ModifierGrid(counts: stats.modifierCounts)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            // Top keys
            if !stats.topKeys.isEmpty {
                HStack {
                    Text("Top Keys")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                TopKeysBar(keys: stats.topKeys)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            // 7-day trend
            if let trend = stats.weeklyTrend {
                WeeklyTrendView(trend: trend)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Metric Row

struct AnalyticRow: View {
    let label: String
    let value: String
    var detail: String? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                if let detail {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Top Keys

struct TopKeysBar: View {
    let keys: [(keyCode: Int, name: String, count: Int, percentage: Double)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys.indices, id: \.self) { i in
                let key = keys[i]
                VStack(spacing: 2) {
                    Text(key.name)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Text(String(format: "%.0f%%", key.percentage))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.08 + 0.12 * Double(keys.count - i) / Double(keys.count)))
                )
            }
        }
    }
}

// MARK: - Weekly Trend

struct WeeklyTrendView: View {
    let trend: WeeklyTrend

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("7-Day Trend")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if trend.changePercent != 0 {
                    HStack(spacing: 2) {
                        Text(trend.changePercent > 0 ? "▲" : "▼")
                            .font(.system(size: 8))
                        Text(String(format: "%.0f%%", abs(trend.changePercent)))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(trend.changePercent > 0 ? .green : .red)
                }
            }

            HStack {
                Text("Avg \(trend.avgWPM) WPM")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(trend.avgWords) words/day")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            SparklineView(values: trend.dailyPeakWPMs)
                .frame(height: 24)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

// MARK: - Modifier Grid

struct ModifierGrid: View {
    let counts: [String: Int]

    private static let labels: [(key: String, symbol: String)] = [
        ("shift", "⇧"), ("cmd", "⌘"), ("opt", "⌥"), ("ctrl", "⌃"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.labels, id: \.key) { item in
                let count = counts[item.key, default: 0]
                VStack(spacing: 2) {
                    Text(item.symbol)
                        .font(.system(size: 11, weight: .medium))
                    Text(formatCount(count))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(count > 0 ? Color.purple.opacity(0.08) : Color.secondary.opacity(0.04))
                )
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 10000 { return "\(n / 1000)k" }
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
}

// MARK: - Sparkline

struct SparklineView: View {
    let values: [Int]

    var body: some View {
        GeometryReader { geo in
            let maxVal = CGFloat(max(values.max() ?? 1, 1))

            // Line
            Path { path in
                let points: [CGPoint] = values.enumerated().map { i, v in
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat(v) / maxVal)
                    return CGPoint(x: x, y: y)
                }
                guard let first = points.first else { return }
                path.move(to: first)
                for pt in points.dropFirst() {
                    path.addLine(to: pt)
                }
            }
            .stroke(Color.accentColor, lineWidth: 1.5)

            // Dots
            ForEach(values.indices, id: \.self) { i in
                let x = geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                let y = geo.size.height * (1 - CGFloat(values[i]) / maxVal)
                Circle()
                    .fill(values[i] > 0 ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 4, height: 4)
                    .position(x: x, y: y)
            }
        }
    }
}
