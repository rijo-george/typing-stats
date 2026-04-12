import SwiftUI

struct OnboardingView: View {
    @Binding var hasAccessibility: Bool
    var onComplete: () -> Void
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 32)

            Spacer()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: accessibilityStep
                default: readyStep
                }
            }

            Spacer()

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.3)) { step -= 1 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                Spacer()
                Button(step < 2 ? "Continue" : "Start Typing") {
                    if step < 2 {
                        withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
                    } else {
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .frame(width: 520, height: 440)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Text("⌨️")
                .font(.system(size: 64))

            Text("Welcome to Typing Stats")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("Track your typing speed, rhythm, and patterns.\nAll private. All local. Nothing leaves your Mac.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "gauge.open.with.lines.needle.33percent",
                           text: "Real-time WPM in your menu bar")
                featureRow(icon: "chart.bar.fill",
                           text: "Deep analytics: rhythm, accuracy, trends")
                featureRow(icon: "figure.wave",
                           text: "Desktop buddy that types along with you")
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 2: Accessibility

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Image(systemName: hasAccessibility ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(hasAccessibility ? .green : .orange)

            Text("Accessibility Access")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("Typing Stats reads keystrokes to measure your speed.\nNo text content is recorded — only timing and key codes.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            if hasAccessibility {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)
                    .padding(.top, 8)
            } else {
                Button("Open System Settings") {
                    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                    AXIsProcessTrustedWithOptions(opts)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 8)

                Text("Grant access, then come back here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 16) {
            Text("🎉")
                .font(.system(size: 64))

            Text("You're All Set")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("Look for the ⌨️ icon in your menu bar.\nClick it anytime to see your typing stats.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "menubar.rectangle",
                           text: "Menu bar icon for quick stats")
                featureRow(icon: "macwindow",
                           text: "Open the dashboard for full analytics")
                featureRow(icon: "square.and.arrow.up",
                           text: "Share or export your daily progress")
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 13))
        }
    }
}
