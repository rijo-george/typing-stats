import SwiftUI

enum TypingAnimal: String, CaseIterable {
    case sloth = "🦥"
    case turtle = "🐢"
    case cat = "🐱"
    case rabbit = "🐰"
    case cheetah = "🐆"

    var label: String {
        switch self {
        case .sloth: return "Sloth mode"
        case .turtle: return "Steady pace"
        case .cat: return "Cruising"
        case .rabbit: return "Speed demon"
        case .cheetah: return "BLAZING"
        }
    }

    var idleLabel: String {
        switch self {
        case .sloth: return "Napping..."
        case .turtle: return "Resting..."
        case .cat: return "Grooming..."
        case .rabbit: return "Snoozing..."
        case .cheetah: return "Stretching..."
        }
    }

    var sleepEmoji: String {
        switch self {
        case .sloth: return "😴"
        case .turtle: return "🐢"
        case .cat: return "😺"
        case .rabbit: return "🐰"
        case .cheetah: return "😴"
        }
    }

    var typingSpeed: Double {
        switch self {
        case .sloth: return 1.0
        case .turtle: return 0.6
        case .cat: return 0.35
        case .rabbit: return 0.18
        case .cheetah: return 0.09
        }
    }

    var bounceHeight: CGFloat {
        switch self {
        case .sloth: return 2
        case .turtle: return 3
        case .cat: return 5
        case .rabbit: return 7
        case .cheetah: return 9
        }
    }

    var color: Color {
        switch self {
        case .sloth: return .brown
        case .turtle: return .green
        case .cat: return .orange
        case .rabbit: return .pink
        case .cheetah: return .yellow
        }
    }

    static func forWPM(_ wpm: Int) -> TypingAnimal {
        switch wpm {
        case 0...20: return .sloth
        case 21...40: return .turtle
        case 41...60: return .cat
        case 61...80: return .rabbit
        default: return .cheetah
        }
    }
}

// MARK: - Desktop Floating Character

struct DesktopCharacterView: View {
    @ObservedObject var stats: StatsEngine
    var onHide: (() -> Void)? = nil
    var onOpenDashboard: (() -> Void)? = nil

    // Typing animation
    @State private var bounce = false
    @State private var leftArm = false
    @State private var rightArm = false
    @State private var speedLinePhase = false
    @State private var transformScale: CGFloat = 1.0

    // Idle state
    @State private var breathPhase = false
    @State private var idleSeconds: Double = 0
    @State private var idleStartTime: Date?

    // Blink
    @State private var blinkSquish = false

    // Hover
    @State private var isHovered = false

    // Milestones
    @State private var milestoneText: String?

    private var animal: TypingAnimal { TypingAnimal.forWPM(stats.currentWPM) }
    private var isTyping: Bool { stats.currentWPM > 0 }
    private var isSleeping: Bool { !isTyping && idleSeconds > 30 }

    var body: some View {
        ZStack {
            // Speed lines (cheetah only)
            if animal == .cheetah && isTyping {
                SpeedLinesDesktop(phase: speedLinePhase)
                    .offset(x: -30, y: -10)
            }

            VStack(spacing: 0) {
                // Status bubble
                statusBubble
                    .frame(height: 26)

                ZStack {
                    // Sweat drops (high speed)
                    if (animal == .rabbit || animal == .cheetah) && isTyping {
                        SweatDrops()
                            .id("sweat-\(animal.rawValue)")
                            .offset(x: -20, y: -15)
                    }

                    // Character body
                    VStack(spacing: -2) {
                        // Head
                        characterHead

                        // Desk scene
                        ZStack {
                            DeskView()
                            HStack(spacing: 20) {
                                ArmView(isDown: leftArm, side: .left, color: animal.color)
                                ArmView(isDown: rightArm, side: .right, color: animal.color)
                            }
                            .offset(y: -12)
                            KeyboardView(leftPress: leftArm, rightPress: rightArm, isTyping: isTyping)
                                .offset(y: -6)
                        }
                    }
                }

                // Status label
                statusLabel
                    .padding(.top, 2)
            }
        }
        .frame(width: 160, height: 160)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovered = hovering }
        }
        .opacity(isHovered ? 0.3 : 1.0)
        .help(isTyping
            ? "\(stats.currentWPM) WPM · \(stats.todayWords) words today"
            : "\(stats.todayWords) words today")
        .contextMenu { contextMenuItems }
        // Breathing (always active)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathPhase = true
            }
            if isTyping { startTypingAnimations() }
        }
        // Typing start/stop
        .onChange(of: isTyping) { _, typing in
            if typing {
                idleStartTime = nil
                idleSeconds = 0
                milestoneText = nil
                startTypingAnimations()
            } else {
                idleStartTime = Date()
                stopTypingAnimations()
            }
        }
        // Animal change pop
        .onChange(of: animal) { oldVal, newVal in
            guard oldVal != newVal else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                transformScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    transformScale = 1.0
                }
            }
            if isTyping { startTypingAnimations() }
        }
        // Blink timer
        .onReceive(Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()) { _ in
            guard !isSleeping else { return }
            guard !isTyping || animal == .sloth else { return }
            withAnimation(.easeInOut(duration: 0.1)) { blinkSquish = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.1)) { blinkSquish = false }
            }
        }
        // Idle timer
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            if let start = idleStartTime {
                withAnimation(.easeInOut(duration: 0.5)) {
                    idleSeconds = Date().timeIntervalSince(start)
                }
            }
        }
        // Milestone: words
        .onChange(of: stats.todayWords) { old, new in
            for m in [100, 500, 1000, 2500, 5000, 10000] {
                if old < m && new >= m {
                    showMilestone("🎉 \(m) words!")
                    break
                }
            }
        }
        // Milestone: peak WPM
        .onChange(of: stats.peakWPM) { old, new in
            if old > 0 && new > old && new >= 20 {
                showMilestone("⚡ Peak \(new) WPM!")
            }
        }
    }

    // MARK: - Character Head

    private var characterHead: some View {
        ZStack {
            Text(animal.rawValue)
                .font(.system(size: 52))

            if isSleeping {
                Text("😴")
                    .font(.system(size: 52))
                    .transition(.opacity)
            }
        }
        .offset(y: isTyping && bounce ? -animal.bounceHeight : 0)
        .scaleEffect(x: 1, y: blinkSquish ? 0.9 : 1.0)
        .scaleEffect(breathPhase ? 1.02 : 1.0)
        .scaleEffect(transformScale)
    }

    // MARK: - Status Bubble

    @ViewBuilder
    private var statusBubble: some View {
        if let milestone = milestoneText {
            Text(milestone)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange.opacity(0.9)))
                .transition(.scale.combined(with: .opacity))
                .offset(x: 10, y: 6)
        } else if isSleeping {
            Text("💤")
                .font(.system(size: 16))
                .offset(x: 24, y: 4)
                .transition(.scale.combined(with: .opacity))
        } else if isTyping {
            WPMBubble(wpm: stats.currentWPM, animal: animal)
                .transition(.scale.combined(with: .opacity))
                .offset(x: 28, y: 8)
        }
    }

    // MARK: - Status Label

    private var statusLabel: some View {
        Group {
            if isSleeping {
                Text(animal.idleLabel)
                    .foregroundStyle(.secondary)
            } else if isTyping {
                Text("\(animal.label) · \(stats.currentWPM) WPM")
                    .foregroundStyle(animal.color)
            } else {
                Text("Waiting for keystrokes...")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Section {
            Text("\(stats.todayWords) words · \(stats.todayKeystrokes) keys")
            if stats.peakWPM > 0 {
                Text("Peak: \(stats.peakWPM) WPM")
            }
        }
        Divider()
        if let onOpenDashboard {
            Button("Open Dashboard") { onOpenDashboard() }
        }
        Divider()
        if let onHide {
            Button("Hide Buddy") { onHide() }
        }
    }

    // MARK: - Animations

    private func startTypingAnimations() {
        let speed = animal.typingSpeed

        // Reset before restarting to avoid stuck states
        bounce = false
        leftArm = false
        rightArm = false
        speedLinePhase = false

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
                bounce = true
            }
            withAnimation(.easeInOut(duration: speed * 0.5).repeatForever(autoreverses: true)) {
                leftArm = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + speed * 0.25) {
                withAnimation(.easeInOut(duration: speed * 0.5).repeatForever(autoreverses: true)) {
                    rightArm = true
                }
            }
            if animal == .cheetah {
                withAnimation(.linear(duration: 0.4).repeatForever(autoreverses: true)) {
                    speedLinePhase = true
                }
            }
        }
    }

    private func stopTypingAnimations() {
        withAnimation(.easeOut(duration: 0.4)) {
            bounce = false
            leftArm = false
            rightArm = false
            speedLinePhase = false
        }
    }

    private func showMilestone(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            milestoneText = text
        }
        // Pop scale
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            transformScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                transformScale = 1.0
            }
        }
        // Dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                milestoneText = nil
            }
        }
    }
}

// MARK: - Sub-components

struct WPMBubble: View {
    let wpm: Int
    let animal: TypingAnimal

    var body: some View {
        Text("\(wpm)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(animal.color.opacity(0.85)))
    }
}

struct DeskView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Desktop surface
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [Color.brown.opacity(0.25), Color.brown.opacity(0.15)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 90, height: 18)

            // Desk edge
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.brown.opacity(0.3))
                .frame(width: 96, height: 4)

            // Desk legs
            HStack(spacing: 70) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.brown.opacity(0.2))
                    .frame(width: 4, height: 14)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.brown.opacity(0.2))
                    .frame(width: 4, height: 14)
            }
        }
    }
}

enum ArmSide { case left, right }

struct ArmView: View {
    let isDown: Bool
    let side: ArmSide
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(0.5))
            .frame(width: 10, height: 18)
            .rotationEffect(.degrees(side == .left ? (isDown ? 5 : -5) : (isDown ? -5 : 5)))
            .offset(y: isDown ? 3 : 0)
    }
}

struct KeyboardView: View {
    let leftPress: Bool
    let rightPress: Bool
    let isTyping: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.darkGray).opacity(0.4))
                .frame(width: 54, height: 18)

            VStack(spacing: 2) {
                keyRow(offset: 0)
                keyRow(offset: 1)
            }
        }
    }

    private func keyRow(offset: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { i in
                let isLeftZone = i < 3
                let pressed = isTyping && (offset == 0
                    ? (isLeftZone ? leftPress : rightPress)
                    : (isLeftZone ? !leftPress : !rightPress))
                RoundedRectangle(cornerRadius: 1)
                    .fill(pressed ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                    .frame(width: 5, height: 4)
                    .scaleEffect(pressed ? 0.85 : 1.0)
            }
        }
    }
}

struct SweatDrops: View {
    @State private var drop1Y: CGFloat = 0
    @State private var drop2Y: CGFloat = 0

    var body: some View {
        ZStack {
            Text("💧").font(.system(size: 8))
                .offset(x: -2, y: drop1Y)
                .opacity(drop1Y > 8 ? 0 : 1)
            Text("💧").font(.system(size: 6))
                .offset(x: 6, y: drop2Y)
                .opacity(drop2Y > 8 ? 0 : 1)
        }
        .onAppear {
            // Reset then animate to ensure clean cycle on view recreation
            drop1Y = 0
            drop2Y = 0
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.8).repeatForever(autoreverses: false)) {
                    drop1Y = 12
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.7).repeatForever(autoreverses: false)) {
                    drop2Y = 12
                }
            }
        }
    }
}

struct SpeedLinesDesktop: View {
    let phase: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.yellow.opacity(phase ? 0.4 : 0.1))
                    .frame(width: CGFloat(10 + i * 6), height: 2)
                    .offset(x: phase ? -3 : 3)
            }
        }
    }
}

// MARK: - Small version for menu bar panel

struct TypingCharacterView: View {
    let currentWPM: Int
    let isTyping: Bool
    @State private var bounce = false

    private var animal: TypingAnimal {
        TypingAnimal.forWPM(currentWPM)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(animal.rawValue)
                .font(.system(size: 20))
                .scaleEffect(bounce ? 1.1 : 1.0)
            Text(isTyping ? animal.label : "Waiting...")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(height: 30)
        .onChange(of: isTyping) { _, typing in
            if typing {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    bounce = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) { bounce = false }
            }
        }
    }
}
