import SwiftUI
import AppKit

struct SnakeGameView: View {
    @Binding var selectedTab: AppTab
    @StateObject private var engine = SnakeGameEngine()
    @State private var keyMonitor: Any?
    @State private var showNamePrompt = false
    @State private var playerName = ""
    @State private var isSubmittingScore = false
    @State private var submissionError: String?
    @State private var showSubmissionError = false
    @State private var showSubmissionSuccess = false
    @State private var scoreSubmitted = false
    @State private var godModeKeyCount = 0

    // Animation state for smooth movement
    @State private var animationProgress: Double = 0.0
    @State private var previousSnakeBody: [Position] = []
    @State private var lastUpdateTime: Date = Date()

    var body: some View {
        ZStack {
            // Background - Desert atmosphere
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.10, blue: 0.08),  // Dark desert night
                    Color(red: 0.18, green: 0.14, blue: 0.10),  // Twilight sand
                    Color(red: 0.22, green: 0.17, blue: 0.12)   // Warm dusk
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Tactical Header HUD
                HStack(alignment: .top, spacing: 0) {
                    // Left: Mission Status
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DESERT RECON")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                            .tracking(2)

                        Text("VIPER TRACKING")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.4))
                            .tracking(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            Color(red: 0.15, green: 0.12, blue: 0.10).opacity(0.8)

                            // Scan line effect
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.03),
                                            Color.white.opacity(0.01),
                                            Color.white.opacity(0.03)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .overlay(
                        Rectangle()
                            .stroke(Color(red: 0.9, green: 0.6, blue: 0.3).opacity(0.3), lineWidth: 1)
                    )

                    Spacer()

                    // Center: God Mode Indicator
                    if engine.godMode {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 1.0, green: 0.8, blue: 0.2))

                            Text("INFINITE MODE")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(red: 1.0, green: 0.8, blue: 0.2))
                                .tracking(1.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.15)

                                // Pulsing glow effect
                                Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.1)
                                    .blur(radius: 8)
                            }
                        )
                        .overlay(
                            Rectangle()
                                .stroke(Color(red: 1.0, green: 0.8, blue: 0.2), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.5), radius: 8)
                    }

                    Spacer()

                    // Right: Score Display
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SCORE")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.4))
                            .tracking(2)

                        Text(String(format: "%06d", engine.score))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                            .shadow(color: Color(red: 0.9, green: 0.6, blue: 0.3).opacity(0.5), radius: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Color(red: 0.15, green: 0.12, blue: 0.10).opacity(0.8)

                            // Glowing edge
                            Rectangle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.9, green: 0.6, blue: 0.3).opacity(0.5),
                                            Color(red: 0.9, green: 0.6, blue: 0.3).opacity(0.1)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

            // Game board - Tactical viewport
            ZStack {
                // Outer tactical frame
                Rectangle()
                    .fill(Color(red: 0.1, green: 0.08, blue: 0.06))
                    .frame(width: GameConstants.boardSize + 20, height: GameConstants.boardSize + 20)
                    .overlay(
                        Rectangle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.9, green: 0.6, blue: 0.3),
                                        Color(red: 0.6, green: 0.4, blue: 0.2),
                                        Color(red: 0.9, green: 0.6, blue: 0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 20)

                // Corner markers (tactical UI elements)
                ForEach(0..<4, id: \.self) { corner in
                    let isTop = corner < 2
                    let isLeft = corner % 2 == 0

                    Path { path in
                        let size: CGFloat = 15
                        let frameOffset = GameConstants.boardSize / 2 + 8
                        let x = isLeft ? -frameOffset : frameOffset
                        let y = isTop ? -frameOffset : frameOffset

                        if isTop && isLeft {
                            path.move(to: CGPoint(x: x, y: y + size))
                            path.addLine(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x + size, y: y))
                        } else if isTop && !isLeft {
                            path.move(to: CGPoint(x: x - size, y: y))
                            path.addLine(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x, y: y + size))
                        } else if !isTop && isLeft {
                            path.move(to: CGPoint(x: x, y: y - size))
                            path.addLine(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x + size, y: y))
                        } else {
                            path.move(to: CGPoint(x: x - size, y: y))
                            path.addLine(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x, y: y - size))
                        }
                    }
                    .stroke(Color(red: 0.9, green: 0.6, blue: 0.3), lineWidth: 2)
                }

                // Desert background viewport
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.75, blue: 0.55),  // Light sand
                                Color(red: 0.8, green: 0.7, blue: 0.5),     // Medium sand
                                Color(red: 0.75, green: 0.65, blue: 0.45)   // Dark sand
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: GameConstants.boardSize, height: GameConstants.boardSize)
                    .overlay(
                        // Vignette effect
                        Rectangle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.clear,
                                        Color.black.opacity(0.3)
                                    ],
                                    center: .center,
                                    startRadius: GameConstants.boardSize * 0.3,
                                    endRadius: GameConstants.boardSize * 0.6
                                )
                            )
                    )

                // Game canvas with 60fps animation
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        updateAnimationProgress(date: timeline.date)

                    // Draw desert terrain texture
                    drawDesertTexture(context: context, size: size)

                    // Draw subtle grid lines (sand ripples)
                    context.stroke(
                        Path { path in
                            for i in 0...GameConstants.gridSize {
                                let offset = CGFloat(i) * GameConstants.cellSize
                                path.move(to: CGPoint(x: offset, y: 0))
                                path.addLine(to: CGPoint(x: offset, y: size.height))
                                path.move(to: CGPoint(x: 0, y: offset))
                                path.addLine(to: CGPoint(x: size.width, y: offset))
                            }
                        },
                        with: .color(Color(red: 0.7, green: 0.6, blue: 0.4).opacity(0.15)),
                        lineWidth: 0.5
                    )

                    // Draw food (3D apple)
                    drawApple(context: context, at: engine.food)

                    // Draw snake with smooth interpolation
                    drawSnake(context: context)
                    }
                    .frame(width: GameConstants.boardSize, height: GameConstants.boardSize)
                }

                // Game state overlay - Tactical display
                if engine.gameState != .playing {
                    ZStack {
                        // Heavy atmospheric overlay
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.05, green: 0.04, blue: 0.03).opacity(0.9),
                                        Color(red: 0.08, green: 0.06, blue: 0.05).opacity(0.95)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: GameConstants.boardSize, height: GameConstants.boardSize)

                        VStack(spacing: 24) {
                            if engine.gameState == .ready {
                                VStack(spacing: 16) {
                                    Text("MISSION READY")
                                        .font(.system(size: 42, weight: .black, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                                        .tracking(3)
                                        .shadow(color: Color(red: 0.9, green: 0.6, blue: 0.3).opacity(0.5), radius: 10)

                                    Rectangle()
                                        .fill(Color(red: 0.9, green: 0.6, blue: 0.3).opacity(0.3))
                                        .frame(width: 200, height: 2)

                                    VStack(spacing: 8) {
                                        Text("OBJECTIVE: TRACK DESERT VIPER")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color(red: 0.7, green: 0.6, blue: 0.5))
                                            .tracking(1.5)

                                        Text("USE ARROW KEYS TO NAVIGATE")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.4))
                                            .tracking(1)
                                    }
                                    .padding(.top, 8)

                                    Text("[ PRESS SPACE TO BEGIN ]")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                                        .tracking(2)
                                        .padding(.top, 12)
                                }
                            } else if engine.gameState == .paused {
                                VStack(spacing: 16) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "pause.fill")
                                            .font(.system(size: 24))
                                        Text("MISSION PAUSED")
                                            .font(.system(size: 36, weight: .black, design: .monospaced))
                                            .tracking(2)
                                    }
                                    .foregroundStyle(Color(red: 1.0, green: 0.8, blue: 0.2))
                                    .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.5), radius: 10)

                                    Text("[ PRESS SPACE TO RESUME ]")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.7, green: 0.6, blue: 0.5))
                                        .tracking(2)
                                }
                            } else if engine.gameState == .gameOver {
                                VStack(spacing: 20) {
                                    VStack(spacing: 12) {
                                        Text("MISSION TERMINATED")
                                            .font(.system(size: 38, weight: .black, design: .monospaced))
                                            .foregroundStyle(Color(red: 0.9, green: 0.3, blue: 0.2))
                                            .tracking(3)
                                            .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.2).opacity(0.6), radius: 12)

                                        Rectangle()
                                            .fill(Color(red: 0.9, green: 0.3, blue: 0.2).opacity(0.4))
                                            .frame(width: 250, height: 2)
                                    }

                                    VStack(spacing: 4) {
                                        Text("FINAL SCORE")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color(red: 0.6, green: 0.5, blue: 0.4))
                                            .tracking(2)

                                        Text(String(format: "%06d", engine.score))
                                            .font(.system(size: 56, weight: .black, design: .monospaced))
                                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                                            .shadow(color: Color(red: 0.9, green: 0.6, blue: 0.3).opacity(0.6), radius: 8)
                                    }
                                    .padding(.vertical, 8)

                                    HStack(spacing: 16) {
                                        Button(action: {
                                            showNamePrompt = true
                                        }) {
                                            Text("SUBMIT SCORE")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .tracking(1.5)
                                                .foregroundStyle(Color(red: 0.1, green: 0.08, blue: 0.06))
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(Color(red: 0.9, green: 0.6, blue: 0.3))
                                                .overlay(
                                                    Rectangle()
                                                        .stroke(Color(red: 0.9, green: 0.6, blue: 0.3), lineWidth: 2)
                                                        .padding(2)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(engine.score == 0 || scoreSubmitted)
                                        .opacity(engine.score == 0 || scoreSubmitted ? 0.4 : 1.0)

                                        Button(action: {
                                            scoreSubmitted = false
                                            godModeKeyCount = 0
                                            engine.resetGame()
                                        }) {
                                            Text("RETRY MISSION")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .tracking(1.5)
                                                .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(Color(red: 0.15, green: 0.12, blue: 0.10))
                                                .overlay(
                                                    Rectangle()
                                                        .stroke(Color(red: 0.9, green: 0.6, blue: 0.3), lineWidth: 2)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Tactical Control Panel
            HStack(spacing: 0) {
                // Left: Controls
                HStack(spacing: 16) {
                    if engine.gameState == .ready {
                        Button(action: {
                            engine.startGame()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("START")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .tracking(1.5)
                            }
                            .foregroundStyle(Color(red: 0.1, green: 0.08, blue: 0.06))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.9, green: 0.6, blue: 0.3))
                            .overlay(
                                Rectangle()
                                    .stroke(Color(red: 0.9, green: 0.6, blue: 0.3), lineWidth: 2)
                                    .padding(2)
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])
                    } else if engine.gameState == .playing {
                        Button(action: {
                            engine.pauseGame()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("PAUSE")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .tracking(1.5)
                            }
                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.15, green: 0.12, blue: 0.10))
                            .overlay(
                                Rectangle()
                                    .stroke(Color(red: 0.9, green: 0.6, blue: 0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])
                    } else if engine.gameState == .paused {
                        Button(action: {
                            engine.resumeGame()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("RESUME")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .tracking(1.5)
                            }
                            .foregroundStyle(Color(red: 0.1, green: 0.08, blue: 0.06))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.9, green: 0.6, blue: 0.3))
                            .overlay(
                                Rectangle()
                                    .stroke(Color(red: 0.9, green: 0.6, blue: 0.3), lineWidth: 2)
                                    .padding(2)
                            )
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])
                    }

                    if engine.gameState != .ready {
                        Button(action: {
                            scoreSubmitted = false
                            godModeKeyCount = 0
                            engine.resetGame()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .bold))
                                Text("RESET")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .tracking(1.5)
                            }
                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.15, green: 0.12, blue: 0.10))
                            .overlay(
                                Rectangle()
                                    .stroke(Color(red: 0.9, green: 0.6, blue: 0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 24)

                Spacer()

                // Right: Key bindings display
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.arrow.down.arrow.left.arrow.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                        Text("ARROW KEYS")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.7, green: 0.6, blue: 0.5))
                            .tracking(1)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "space")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.3))
                        Text("PAUSE / RESUME")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.7, green: 0.6, blue: 0.5))
                            .tracking(1)
                    }
                }
                .padding(.trailing, 24)
            }
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Color(red: 0.10, green: 0.08, blue: 0.06).opacity(0.9)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                Rectangle()
                    .stroke(Color(red: 0.9, green: 0.6, blue: 0.3).opacity(0.2), lineWidth: 1),
                alignment: .top
            )
            }
            .padding(.bottom, 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupKeyboardMonitoring()
        }
        .onDisappear {
            removeKeyboardMonitoring()
        }
        .alert("Submit Your Score", isPresented: $showNamePrompt) {
            TextField("Enter your name", text: $playerName)
            Button("Cancel") {
                showNamePrompt = false
            }
            Button("Submit") {
                Task {
                    await submitScore()
                }
            }
            .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty || isSubmittingScore)
        } message: {
            Text("Score: \(engine.score)")
        }
        .alert("Submission Error", isPresented: $showSubmissionError) {
            Button("OK") {
                showSubmissionError = false
            }
            Button("Retry") {
                showNamePrompt = true
            }
        } message: {
            if let submissionError {
                Text(submissionError)
            }
        }
        .alert("Score Submitted!", isPresented: $showSubmissionSuccess) {
            Button("View Leaderboard") {
                showSubmissionSuccess = false
                selectedTab = .leaderboard
            }
            Button("Play Again") {
                showSubmissionSuccess = false
                scoreSubmitted = false
                godModeKeyCount = 0
                engine.resetGame()
            }
        } message: {
            Text("Your score of \(engine.score) has been added to the leaderboard!")
        }
    }

    // MARK: - Score Submission

    private func submitScore() async {
        let trimmedName = playerName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        isSubmittingScore = true
        showNamePrompt = false

        do {
            _ = try await APIClient.shared.submitScore(playerName: trimmedName, score: engine.score)
            playerName = ""
            scoreSubmitted = true
            showSubmissionSuccess = true
        } catch {
            submissionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
            showSubmissionError = true
        }

        isSubmittingScore = false
    }

    // MARK: - Keyboard Monitoring

    private func setupKeyboardMonitoring() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyPress(event)
            return event
        }
    }

    private func removeKeyboardMonitoring() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyPress(_ event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            engine.changeDirection(.up)
            godModeKeyCount = 0
        case 125: // Down arrow
            engine.changeDirection(.down)
            godModeKeyCount = 0
        case 123: // Left arrow
            engine.changeDirection(.left)
            godModeKeyCount = 0
        case 124: // Right arrow
            engine.changeDirection(.right)
            godModeKeyCount = 0
        case 49: // Space bar
            handleSpaceBar()
            godModeKeyCount = 0
        case 31: // O key - god mode cheat code
            if engine.gameState == .paused {
                godModeKeyCount += 1
                if godModeKeyCount >= 5 {
                    engine.toggleGodMode()
                    godModeKeyCount = 0
                }
            } else {
                godModeKeyCount = 0
            }
        default:
            // Reset counter if any other key is pressed
            godModeKeyCount = 0
            break
        }
    }

    private func handleSpaceBar() {
        switch engine.gameState {
        case .ready:
            engine.startGame()
        case .playing:
            engine.pauseGame()
        case .paused:
            engine.resumeGame()
        case .gameOver:
            break
        }
    }

    // MARK: - Animation Helpers

    private func updateAnimationProgress(date: Date) {
        let timeSinceLastUpdate = date.timeIntervalSince(lastUpdateTime)
        let progress = min(1.0, timeSinceLastUpdate / engine.currentSpeed)

        // Store previous positions when snake body changes
        if previousSnakeBody != engine.snake.body {
            previousSnakeBody = engine.snake.body
            lastUpdateTime = date
            animationProgress = 0.0
        } else {
            animationProgress = progress
        }
    }

    private func gridToScreen(_ position: Position) -> CGPoint {
        CGPoint(
            x: CGFloat(position.x) * GameConstants.cellSize + GameConstants.cellSize / 2,
            y: CGFloat(position.y) * GameConstants.cellSize + GameConstants.cellSize / 2
        )
    }

    private func interpolatedPosition(_ current: Position, _ previous: Position?, _ progress: Double) -> CGPoint {
        guard let prev = previous, progress < 1.0 else {
            return gridToScreen(current)
        }
        let currentPt = gridToScreen(current)
        let prevPt = gridToScreen(prev)
        return CGPoint(
            x: prevPt.x + (currentPt.x - prevPt.x) * progress,
            y: prevPt.y + (currentPt.y - prevPt.y) * progress
        )
    }

    // MARK: - Drawing Functions

    private func drawSnake(context: GraphicsContext) {
        let body = engine.snake.body
        guard !body.isEmpty else { return }

        // Calculate interpolated positions
        var interpolatedPositions: [CGPoint] = []
        for (index, position) in body.enumerated() {
            let previousPos = index < previousSnakeBody.count ? previousSnakeBody[index] : nil
            let interpolated = interpolatedPosition(position, previousPos, animationProgress)
            interpolatedPositions.append(interpolated)
        }

        // Draw body segments with neumorphic effect
        for (index, position) in interpolatedPositions.enumerated() {
            if index == 0 {
                // Draw head
                drawSnakeHead(context: context, position: position, direction: engine.currentVisualDirection)
            } else {
                // Draw body segment
                let rect = CGRect(
                    x: position.x - GameConstants.cellSize / 2 + 1,
                    y: position.y - GameConstants.cellSize / 2 + 1,
                    width: GameConstants.cellSize - 2,
                    height: GameConstants.cellSize - 2
                )

                // Realistic snake body coloring - olive green with pattern
                let baseColor = Color(red: 0.4, green: 0.6, blue: 0.2)  // Olive green
                let patternColor = Color(red: 0.25, green: 0.4, blue: 0.15)  // Darker green
                let bellyColor = Color(red: 0.7, green: 0.8, blue: 0.5)  // Light yellow-green

                // Draw body segment with gradient (darker on top, lighter on bottom for 3D effect)
                let bodyGradient = Gradient(colors: [patternColor, baseColor, bellyColor])
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 6),
                    with: .linearGradient(
                        bodyGradient,
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    )
                )

                // Add scale pattern texture
                drawScalePattern(context: context, in: rect, segmentIndex: index)

                // Inner shadow for depth
                var innerShadowContext = context
                innerShadowContext.addFilter(.shadow(color: .black.opacity(0.3), radius: 2, x: -1, y: -1))
                innerShadowContext.fill(
                    Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 5),
                    with: .color(.black.opacity(0.05))
                )
            }
        }
    }

    private func drawSnakeHead(context: GraphicsContext, position: CGPoint, direction: Direction) {
        let headSize = GameConstants.cellSize - 2

        // Realistic snake colors
        let headBaseColor = Color(red: 0.35, green: 0.55, blue: 0.2)  // Olive green
        let headDarkColor = Color(red: 0.2, green: 0.35, blue: 0.1)  // Dark green pattern
        let headLightColor = Color(red: 0.65, green: 0.75, blue: 0.45)  // Light belly

        // Create triangular/diamond head shape based on direction
        var headPath = Path()

        switch direction {
        case .right:
            // Head pointing right (triangle)
            headPath.move(to: CGPoint(x: position.x + headSize/2, y: position.y))  // Tip
            headPath.addLine(to: CGPoint(x: position.x - headSize/3, y: position.y - headSize/2.5))  // Top left
            headPath.addLine(to: CGPoint(x: position.x - headSize/2, y: position.y))  // Back center
            headPath.addLine(to: CGPoint(x: position.x - headSize/3, y: position.y + headSize/2.5))  // Bottom left
            headPath.closeSubpath()

        case .left:
            // Head pointing left
            headPath.move(to: CGPoint(x: position.x - headSize/2, y: position.y))  // Tip
            headPath.addLine(to: CGPoint(x: position.x + headSize/3, y: position.y - headSize/2.5))  // Top right
            headPath.addLine(to: CGPoint(x: position.x + headSize/2, y: position.y))  // Back center
            headPath.addLine(to: CGPoint(x: position.x + headSize/3, y: position.y + headSize/2.5))  // Bottom right
            headPath.closeSubpath()

        case .up:
            // Head pointing up
            headPath.move(to: CGPoint(x: position.x, y: position.y - headSize/2))  // Tip
            headPath.addLine(to: CGPoint(x: position.x - headSize/2.5, y: position.y + headSize/3))  // Left
            headPath.addLine(to: CGPoint(x: position.x, y: position.y + headSize/2))  // Back center
            headPath.addLine(to: CGPoint(x: position.x + headSize/2.5, y: position.y + headSize/3))  // Right
            headPath.closeSubpath()

        case .down:
            // Head pointing down
            headPath.move(to: CGPoint(x: position.x, y: position.y + headSize/2))  // Tip
            headPath.addLine(to: CGPoint(x: position.x - headSize/2.5, y: position.y - headSize/3))  // Left
            headPath.addLine(to: CGPoint(x: position.x, y: position.y - headSize/2))  // Back center
            headPath.addLine(to: CGPoint(x: position.x + headSize/2.5, y: position.y - headSize/3))  // Right
            headPath.closeSubpath()
        }

        // Draw shadow
        var shadowContext = context
        shadowContext.addFilter(.shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 1))
        shadowContext.fill(headPath, with: .color(headBaseColor))

        // Fill head with gradient
        let headGradient = Gradient(colors: [headDarkColor, headBaseColor, headLightColor])
        context.fill(
            headPath,
            with: .linearGradient(
                headGradient,
                startPoint: CGPoint(x: position.x - headSize/2, y: position.y - headSize/2),
                endPoint: CGPoint(x: position.x + headSize/2, y: position.y + headSize/2)
            )
        )

        // Add pattern/scales on top of head
        drawHeadPattern(context: context, position: position, direction: direction, headSize: headSize)

        // Draw realistic reptilian eyes with vertical slit pupils
        drawReptilianEyes(context: context, position: position, direction: direction, headSize: headSize)

        // Draw nostrils
        drawNostrils(context: context, position: position, direction: direction, headSize: headSize)
    }

    private func drawReptilianEyes(context: GraphicsContext, position: CGPoint, direction: Direction, headSize: CGFloat) {
        // Eye positions based on direction
        let eyePositions: [(CGPoint, CGPoint)] = {
            switch direction {
            case .right:
                return [
                    (CGPoint(x: position.x + headSize/6, y: position.y - headSize/4), CGPoint(x: position.x + headSize/6, y: position.y + headSize/4))
                ]
            case .left:
                return [
                    (CGPoint(x: position.x - headSize/6, y: position.y - headSize/4), CGPoint(x: position.x - headSize/6, y: position.y + headSize/4))
                ]
            case .up:
                return [
                    (CGPoint(x: position.x - headSize/4, y: position.y - headSize/6), CGPoint(x: position.x + headSize/4, y: position.y - headSize/6))
                ]
            case .down:
                return [
                    (CGPoint(x: position.x - headSize/4, y: position.y + headSize/6), CGPoint(x: position.x + headSize/4, y: position.y + headSize/6))
                ]
            }
        }()

        for eyePos in [eyePositions[0].0, eyePositions[0].1] {
            // Eye socket (darker outline)
            let eyeSocketSize: CGFloat = 5
            context.fill(
                Path(ellipseIn: CGRect(
                    x: eyePos.x - eyeSocketSize/2,
                    y: eyePos.y - eyeSocketSize/2,
                    width: eyeSocketSize,
                    height: eyeSocketSize
                )),
                with: .color(Color(red: 0.15, green: 0.2, blue: 0.1))
            )

            // Eye (yellow-green with black outline)
            let eyeSize: CGFloat = 4
            context.fill(
                Path(ellipseIn: CGRect(
                    x: eyePos.x - eyeSize/2,
                    y: eyePos.y - eyeSize/2,
                    width: eyeSize,
                    height: eyeSize
                )),
                with: .color(Color(red: 0.8, green: 0.85, blue: 0.3))
            )

            // Vertical slit pupil (like a real snake)
            let pupilWidth: CGFloat = 0.8
            let pupilHeight: CGFloat = 3
            context.fill(
                Path(roundedRect: CGRect(
                    x: eyePos.x - pupilWidth/2,
                    y: eyePos.y - pupilHeight/2,
                    width: pupilWidth,
                    height: pupilHeight
                ), cornerRadius: 0.4),
                with: .color(.black)
            )

            // Eye shine
            let shineSize: CGFloat = 1
            context.fill(
                Path(ellipseIn: CGRect(
                    x: eyePos.x - 1,
                    y: eyePos.y - 1.5,
                    width: shineSize,
                    height: shineSize
                )),
                with: .color(.white.opacity(0.7))
            )
        }
    }

    private func drawNostrils(context: GraphicsContext, position: CGPoint, direction: Direction, headSize: CGFloat) {
        let nostrilPositions: [CGPoint] = {
            switch direction {
            case .right:
                return [
                    CGPoint(x: position.x + headSize/3, y: position.y - 2),
                    CGPoint(x: position.x + headSize/3, y: position.y + 2)
                ]
            case .left:
                return [
                    CGPoint(x: position.x - headSize/3, y: position.y - 2),
                    CGPoint(x: position.x - headSize/3, y: position.y + 2)
                ]
            case .up:
                return [
                    CGPoint(x: position.x - 2, y: position.y - headSize/3),
                    CGPoint(x: position.x + 2, y: position.y - headSize/3)
                ]
            case .down:
                return [
                    CGPoint(x: position.x - 2, y: position.y + headSize/3),
                    CGPoint(x: position.x + 2, y: position.y + headSize/3)
                ]
            }
        }()

        for nostrilPos in nostrilPositions {
            context.fill(
                Path(ellipseIn: CGRect(
                    x: nostrilPos.x - 0.8,
                    y: nostrilPos.y - 0.8,
                    width: 1.6,
                    height: 1.6
                )),
                with: .color(Color(red: 0.1, green: 0.15, blue: 0.05).opacity(0.8))
            )
        }
    }

    private func drawHeadPattern(context: GraphicsContext, position: CGPoint, direction: Direction, headSize: CGFloat) {
        // Add dark stripe pattern on head
        let patternColor = Color(red: 0.2, green: 0.3, blue: 0.1).opacity(0.5)

        // Draw a few small dark spots/stripes for pattern
        let patternRect1 = CGRect(
            x: position.x - 3,
            y: position.y - 5,
            width: 6,
            height: 2
        )
        context.fill(Path(ellipseIn: patternRect1), with: .color(patternColor))

        let patternRect2 = CGRect(
            x: position.x - 3,
            y: position.y + 3,
            width: 6,
            height: 2
        )
        context.fill(Path(ellipseIn: patternRect2), with: .color(patternColor))
    }

    private func drawScalePattern(context: GraphicsContext, in rect: CGRect, segmentIndex: Int) {
        // Draw subtle scale pattern on body
        let scaleColor = Color(red: 0.2, green: 0.35, blue: 0.1).opacity(0.3)

        // Alternating pattern based on segment index
        let offset = CGFloat(segmentIndex % 2) * 3

        // Draw small overlapping circles to simulate scales
        let scaleSize: CGFloat = 4
        let spacing: CGFloat = 3

        for x in stride(from: rect.minX + offset, to: rect.maxX, by: spacing) {
            for y in stride(from: rect.minY, to: rect.maxY, by: spacing) {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: x,
                        y: y,
                        width: scaleSize,
                        height: scaleSize
                    )),
                    with: .color(scaleColor)
                )
            }
        }
    }

    private func drawDesertTexture(context: GraphicsContext, size: CGSize) {
        // Draw sand texture with random variations
        let sandDarkColor = Color(red: 0.7, green: 0.6, blue: 0.4).opacity(0.15)
        let sandLightColor = Color(red: 0.9, green: 0.8, blue: 0.65).opacity(0.1)

        // Draw sand dunes pattern (wavy lines)
        for y in stride(from: CGFloat(0), to: size.height, by: 40) {
            var dunePath = Path()
            dunePath.move(to: CGPoint(x: 0, y: y))

            for x in stride(from: CGFloat(0), to: size.width, by: 30) {
                let waveHeight: CGFloat = sin(x / 50) * 8
                dunePath.addLine(to: CGPoint(x: x, y: y + waveHeight))
            }

            context.stroke(dunePath, with: .color(sandDarkColor), lineWidth: 2)
        }

        // Draw small rocks scattered around (static positions)
        let rockColor = Color(red: 0.5, green: 0.4, blue: 0.3).opacity(0.4)
        let rockPositions: [(CGFloat, CGFloat, CGFloat)] = [
            (50, 80, 6),
            (420, 150, 5),
            (200, 350, 7),
            (380, 420, 5),
            (120, 280, 4),
            (300, 100, 6),
            (150, 480, 5),
            (450, 320, 7)
        ]

        for (x, y, size) in rockPositions {
            // Draw irregular rock shape
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: size, height: size * 0.8)),
                with: .color(rockColor)
            )
            // Add shadow for rock
            context.fill(
                Path(ellipseIn: CGRect(x: x + 1, y: y + size * 0.6, width: size, height: size * 0.3)),
                with: .color(Color.black.opacity(0.15))
            )
        }

        // Add some sand grain texture
        for _ in 0..<50 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let grainSize = CGFloat.random(in: 0.5...1.5)

            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: grainSize, height: grainSize)),
                with: .color(sandLightColor)
            )
        }

        // Draw small cacti silhouettes (optional desert elements)
        drawCactus(context: context, at: CGPoint(x: 30, y: 30), size: 12)
        drawCactus(context: context, at: CGPoint(x: 470, y: 450), size: 10)
    }

    private func drawCactus(context: GraphicsContext, at position: CGPoint, size: CGFloat) {
        let cactusColor = Color(red: 0.3, green: 0.5, blue: 0.2).opacity(0.3)

        // Main trunk
        let trunkRect = CGRect(
            x: position.x - size/4,
            y: position.y,
            width: size/2,
            height: size
        )
        context.fill(
            Path(roundedRect: trunkRect, cornerRadius: size/6),
            with: .color(cactusColor)
        )

        // Left arm
        let leftArmRect = CGRect(
            x: position.x - size/2,
            y: position.y + size/3,
            width: size/3,
            height: size/2.5
        )
        context.fill(
            Path(roundedRect: leftArmRect, cornerRadius: size/8),
            with: .color(cactusColor)
        )

        // Right arm
        let rightArmRect = CGRect(
            x: position.x + size/6,
            y: position.y + size/2.5,
            width: size/3,
            height: size/3
        )
        context.fill(
            Path(roundedRect: rightArmRect, cornerRadius: size/8),
            with: .color(cactusColor)
        )
    }

    private func drawApple(context: GraphicsContext, at position: Position) {
        let center = gridToScreen(position)
        let appleSize = GameConstants.cellSize - 6
        let rect = CGRect(
            x: center.x - appleSize / 2,
            y: center.y - appleSize / 2,
            width: appleSize,
            height: appleSize
        )

        // Shadow underneath
        var shadowContext = context
        shadowContext.addFilter(.shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2))
        shadowContext.fill(
            Path(ellipseIn: rect.offsetBy(dx: 0, dy: 1)),
            with: .color(.black.opacity(0.1))
        )

        // Apple body with radial gradient
        let gradient = Gradient(colors: [
            Color(red: 1.0, green: 0.3, blue: 0.2),  // bright red (top)
            Color(red: 0.8, green: 0.1, blue: 0.1),  // dark red (middle)
            Color(red: 0.6, green: 0.05, blue: 0.05) // shadow red (bottom)
        ])

        let gradientCenter = CGPoint(x: center.x - appleSize * 0.15, y: center.y - appleSize * 0.15)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                gradient,
                center: gradientCenter,
                startRadius: 0,
                endRadius: appleSize * 0.6
            )
        )

        // Highlight spot for 3D effect
        let highlightSize: CGFloat = 5
        let highlightRect = CGRect(
            x: center.x - appleSize / 4,
            y: center.y - appleSize / 4,
            width: highlightSize,
            height: highlightSize
        )
        context.fill(
            Path(ellipseIn: highlightRect),
            with: .color(.white.opacity(0.7))
        )

        // Stem (small brown rectangle at top)
        let stemWidth: CGFloat = 2
        let stemHeight: CGFloat = 4
        let stemRect = CGRect(
            x: center.x - stemWidth / 2,
            y: center.y - appleSize / 2 + 1,
            width: stemWidth,
            height: stemHeight
        )
        context.fill(
            Path(roundedRect: stemRect, cornerRadius: 1),
            with: .color(Color(red: 0.4, green: 0.2, blue: 0.1))
        )

        // Leaf (small green ellipse)
        let leafRect = CGRect(
            x: center.x + 1,
            y: center.y - appleSize / 2,
            width: 3,
            height: 2
        )
        context.fill(
            Path(ellipseIn: leafRect),
            with: .color(Color(red: 0.2, green: 0.6, blue: 0.1))
        )
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .snakeGame
    SnakeGameView(selectedTab: $selectedTab)
        .frame(width: 700, height: 800)
}
