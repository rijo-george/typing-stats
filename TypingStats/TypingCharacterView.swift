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

// MARK: - Desktop floating character (bottom-right overlay)

struct DesktopCharacterView: View {
    @ObservedObject var stats: StatsEngine
    @State private var bounce = false
    @State private var leftArm = false
    @State private var rightArm = false
    @State private var eyeBlink = false
    @State private var speedLinePhase = false
    @State private var sweatY: CGFloat = 0
    @State private var lastAnimal: TypingAnimal = .sloth
    @State private var transformScale: CGFloat = 1.0
    @State private var blinkTimer: Timer?
    @State private var isHovered = false

    private var animal: TypingAnimal {
        TypingAnimal.forWPM(stats.currentWPM)
    }

    private var isTyping: Bool {
        stats.currentWPM > 0
    }

    var body: some View {
        ZStack {
            // Speed lines behind everything
            if animal == .cheetah && isTyping {
                SpeedLinesDesktop(phase: speedLinePhase)
                    .offset(x: -30, y: -10)
            }

            VStack(spacing: 0) {
                // WPM bubble
                if isTyping {
                    WPMBubble(wpm: stats.currentWPM, animal: animal)
                        .transition(.scale.combined(with: .opacity))
                        .offset(x: 28, y: 8)
                }

                ZStack {
                    // Sweat drops for fast typers
                    if (animal == .rabbit || animal == .cheetah) && isTyping {
                        SweatDrops(animating: isTyping)
                            .offset(x: -20, y: -15)
                    }

                    // The character body
                    VStack(spacing: -2) {
                        // Head
                        Text(animal.rawValue)
                            .font(.system(size: 52))
                            .offset(y: isTyping && bounce ? -animal.bounceHeight : 0)
                            .scaleEffect(transformScale)
                            .overlay(
                                // Blink overlay
                                eyeBlink ?
                                    Text("😌")
                                        .font(.system(size: 52))
                                        .transition(.opacity)
                                    : nil
                            )

                        // Arms + Desk area
                        ZStack {
                            // Desk
                            DeskView()

                            // Arms typing
                            HStack(spacing: 20) {
                                // Left paw/arm
                                ArmView(isDown: leftArm, side: .left, color: animal.color)
                                // Right paw/arm
                                ArmView(isDown: rightArm, side: .right, color: animal.color)
                            }
                            .offset(y: -12)

                            // Keyboard on desk
                            KeyboardView(leftPress: leftArm, rightPress: rightArm, isTyping: isTyping)
                                .offset(y: -6)
                        }
                    }
                }

                // Label
                Text(isTyping ? "\(animal.label) · \(stats.currentWPM) WPM" : "Waiting for keystrokes...")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isTyping ? animal.color : .secondary)
                    .padding(.top, 2)
            }
        }
        .frame(width: 160, height: 160)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .opacity(isHovered ? 0.3 : 1.0)
        .allowsHitTesting(true)
        .onChange(of: isTyping) { _, typing in
            if typing { startAnimations() } else { stopAnimations() }
        }
        .onChange(of: animal) { oldVal, newVal in
            if oldVal != newVal {
                // Fun scale pop on animal change
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    transformScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        transformScale = 1.0
                    }
                }
                if isTyping { startAnimations() }
            }
        }
        .onAppear {
            startBlinkTimer()
            if isTyping { startAnimations() }
        }
        .onDisappear {
            blinkTimer?.invalidate()
        }
    }

    private func startAnimations() {
        let speed = animal.typingSpeed

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
        } else {
            speedLinePhase = false
        }
    }

    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.4)) {
            bounce = false
            leftArm = false
            rightArm = false
            speedLinePhase = false
        }
    }

    private func startBlinkTimer() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            guard !isTyping || animal == .sloth else { return }
            withAnimation(.easeInOut(duration: 0.15)) { eyeBlink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.15)) { eyeBlink = false }
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
            .background(
                Capsule().fill(animal.color.opacity(0.85))
            )
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
            // Keyboard body
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.darkGray).opacity(0.4))
                .frame(width: 54, height: 18)

            // Key rows
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { i in
                        let isLeftZone = i < 3
                        let pressed = isTyping && (isLeftZone ? leftPress : rightPress)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(pressed ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                            .frame(width: 5, height: 4)
                            .scaleEffect(pressed ? 0.85 : 1.0)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { i in
                        let isLeftZone = i < 3
                        let pressed = isTyping && (isLeftZone ? !leftPress : !rightPress)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(pressed ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                            .frame(width: 5, height: 4)
                            .scaleEffect(pressed ? 0.85 : 1.0)
                    }
                }
            }
        }
    }
}

struct SweatDrops: View {
    let animating: Bool
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
            withAnimation(.easeIn(duration: 0.8).repeatForever(autoreverses: false)) {
                drop1Y = 12
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

    private var animal: TypingAnimal {
        TypingAnimal.forWPM(currentWPM)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(animal.rawValue)
                .font(.system(size: 20))
            Text(isTyping ? animal.label : "Waiting...")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(height: 30)
    }
}
