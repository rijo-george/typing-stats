import SwiftUI

private let decimalFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return f
}()

struct SummaryView: View {
    let keystrokes: Int
    let words: Int
    let peakWPM: Int
    let activeTime: String
    let comparison: String
    let currentWPM: Int
    let isTyping: Bool
    let keystrokesPerHour: [Int: Int]

    var body: some View {
        VStack(spacing: 0) {
            // Animated character
            TypingCharacterView(currentWPM: currentWPM, isTyping: isTyping)
                .padding(.top, 10)
                .padding(.bottom, 4)

            // Header
            VStack(spacing: 4) {
                Text("Today's Typing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(formattedWords)
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("words typed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            // Fun comparison
            Text(comparison)
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // Activity chart
            if !keystrokesPerHour.isEmpty {
                ActivityChart(data: keystrokesPerHour)
                    .frame(height: 40)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Stats grid
            Divider()
                .padding(.horizontal, 16)

            HStack(spacing: 0) {
                StatCell(value: formattedKeystrokes, label: "Keystrokes")
                Divider().frame(height: 36)
                StatCell(value: "\(peakWPM)", label: "Peak WPM")
                Divider().frame(height: 36)
                StatCell(value: activeTime, label: "Active")
            }
            .padding(.vertical, 10)
        }
        .frame(width: 260)
    }

    private var formattedWords: String {
        decimalFormatter.string(from: NSNumber(value: words)) ?? "\(words)"
    }

    private var formattedKeystrokes: String {
        if keystrokes >= 10000 {
            return "\(keystrokes / 1000)k"
        }
        return decimalFormatter.string(from: NSNumber(value: keystrokes)) ?? "\(keystrokes)"
    }
}

struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActivityChart: View {
    let data: [Int: Int]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<24, id: \.self) { hour in
                let count = data[hour, default: 0]
                let maxCount = data.values.max() ?? 1
                let height = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(count > 0 ? Color.accentColor.opacity(0.4 + 0.6 * height) : Color.secondary.opacity(0.15))
                    .frame(maxWidth: .infinity, minHeight: 3)
                    .frame(height: max(3, height * 36))
            }
        }
    }
}

// Shareable card for export
struct ShareableCard: View {
    let keystrokes: Int
    let words: Int
    let peakWPM: Int
    let activeTime: String
    let comparison: String
    let date: String

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Typing Stats")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(date)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Text(formattedWords)
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Text("words typed")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Text(comparison)
                .font(.system(size: 13))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text(formattedKeystrokes)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("keystrokes")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(peakWPM)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("peak WPM")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text(activeTime)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("active")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
        .frame(width: 340)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8, y: 4)
    }

    private var formattedWords: String {
        decimalFormatter.string(from: NSNumber(value: words)) ?? "\(words)"
    }

    private var formattedKeystrokes: String {
        decimalFormatter.string(from: NSNumber(value: keystrokes)) ?? "\(keystrokes)"
    }
}
