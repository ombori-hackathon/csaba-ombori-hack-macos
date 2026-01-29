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

                // Photorealistic snake body with advanced shading
                let baseColor = Color(red: 0.38, green: 0.55, blue: 0.22)  // Rich olive green
                let darkScale = Color(red: 0.22, green: 0.38, blue: 0.14)  // Deep shadow green
                let lightScale = Color(red: 0.52, green: 0.68, blue: 0.32)  // Highlight green
                let bellyColor = Color(red: 0.72, green: 0.78, blue: 0.55)  // Pale yellow-green

                // Drop shadow for 3D depth
                var shadowCtx = context
                shadowCtx.addFilter(.shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2))
                shadowCtx.fill(Path(roundedRect: rect, cornerRadius: 7), with: .color(baseColor))

                // Main body with radial gradient for cylindrical appearance
                let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
                let bodyGradient = Gradient(colors: [
                    lightScale,      // Top highlight
                    baseColor,       // Mid tone
                    darkScale,       // Shadow
                    bellyColor       // Bottom belly
                ])
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 7),
                    with: .radialGradient(
                        bodyGradient,
                        center: CGPoint(x: centerPoint.x - 3, y: centerPoint.y - 3),
                        startRadius: 2,
                        endRadius: GameConstants.cellSize * 0.7
                    )
                )

                // Detailed scale pattern with individual highlights
                drawPhotorealisticScales(context: context, in: rect, segmentIndex: index)

                // Subsurface scattering effect (light bleeding through edges)
                context.fill(
                    Path(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 6),
                    with: .color(lightScale.opacity(0.15))
                )

                // Specular highlight on top edge
                let highlightRect = CGRect(
                    x: rect.minX + 3,
                    y: rect.minY + 2,
                    width: rect.width - 6,
                    height: 3
                )
                context.fill(
                    Path(ellipseIn: highlightRect),
                    with: .color(.white.opacity(0.25))
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

    private func drawPhotorealisticScales(context: GraphicsContext, in rect: CGRect, segmentIndex: Int) {
        // Advanced scale rendering with individual highlights and shadows
        let scaleBaseColor = Color(red: 0.28, green: 0.42, blue: 0.18).opacity(0.6)
        let scaleHighlight = Color(red: 0.55, green: 0.70, blue: 0.35).opacity(0.4)
        let scaleShadow = Color(red: 0.15, green: 0.25, blue: 0.10).opacity(0.5)

        // Alternating pattern for organic look
        let offset = CGFloat(segmentIndex % 2) * 2.5

        // Draw overlapping scales with 3D effect
        let scaleWidth: CGFloat = 5
        let scaleHeight: CGFloat = 4
        let spacing: CGFloat = 3.5

        for x in stride(from: rect.minX + offset, to: rect.maxX - 1, by: spacing) {
            for y in stride(from: rect.minY, to: rect.maxY - 1, by: spacing) {
                let scaleRect = CGRect(
                    x: x,
                    y: y,
                    width: scaleWidth,
                    height: scaleHeight
                )

                // Shadow under each scale
                context.fill(
                    Path(ellipseIn: scaleRect.offsetBy(dx: 0.5, dy: 0.5)),
                    with: .color(scaleShadow)
                )

                // Main scale body
                context.fill(
                    Path(ellipseIn: scaleRect),
                    with: .color(scaleBaseColor)
                )

                // Highlight on top-left of each scale
                let highlightRect = CGRect(
                    x: x + 0.5,
                    y: y + 0.5,
                    width: scaleWidth * 0.5,
                    height: scaleHeight * 0.5
                )
                context.fill(
                    Path(ellipseIn: highlightRect),
                    with: .color(scaleHighlight)
                )

                // Specular dot on each scale
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: x + 1,
                        y: y + 1,
                        width: 1,
                        height: 1
                    )),
                    with: .color(.white.opacity(0.3))
                )
            }
        }

        // Add diamond pattern overlay for realism
        let patternColor = Color(red: 0.2, green: 0.35, blue: 0.12).opacity(0.25)
        let diamondSize: CGFloat = 8
        for x in stride(from: rect.minX + 4, to: rect.maxX - 4, by: diamondSize) {
            for y in stride(from: rect.minY + 4, to: rect.maxY - 4, by: diamondSize) {
                var diamondPath = Path()
                diamondPath.move(to: CGPoint(x: x, y: y - 3))
                diamondPath.addLine(to: CGPoint(x: x + 3, y: y))
                diamondPath.addLine(to: CGPoint(x: x, y: y + 3))
                diamondPath.addLine(to: CGPoint(x: x - 3, y: y))
                diamondPath.closeSubpath()

                context.fill(diamondPath, with: .color(patternColor))
            }
        }
    }

    private func drawDesertTexture(context: GraphicsContext, size: CGSize) {
        // Photorealistic desert sand with advanced texturing

        // Layer 1: Base sand ripples with depth
        let rippleColor = Color(red: 0.72, green: 0.62, blue: 0.44).opacity(0.25)
        let rippleShadow = Color(red: 0.58, green: 0.50, blue: 0.36).opacity(0.18)

        for y in stride(from: CGFloat(0), to: size.height, by: 35) {
            var ripplePath = Path()
            ripplePath.move(to: CGPoint(x: 0, y: y))

            // Create organic wave pattern
            for x in stride(from: CGFloat(0), to: size.width, by: 15) {
                let waveHeight = sin(x / 45 + y / 60) * 6
                let noise = cos(x / 25) * 2
                ripplePath.addLine(to: CGPoint(x: x, y: y + waveHeight + noise))
            }
            ripplePath.addLine(to: CGPoint(x: size.width, y: y))

            // Shadow side of ripple
            context.stroke(ripplePath, with: .color(rippleShadow), lineWidth: 3)
            // Highlight side
            context.stroke(ripplePath, with: .color(rippleColor), lineWidth: 1.5)
        }

        // Layer 2: Fine sand grain texture (dense)
        for _ in 0..<200 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let grainSize = CGFloat.random(in: 0.5...1.8)
            let opacity = Double.random(in: 0.08...0.15)

            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: grainSize, height: grainSize)),
                with: .color(Color(red: 0.85, green: 0.75, blue: 0.58).opacity(opacity))
            )
        }

        // Layer 3: Sand shadows and highlights for depth
        for _ in 0..<30 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let patchSize = CGFloat.random(in: 8...20)

            // Dark sand patch
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: patchSize, height: patchSize * 0.7)),
                with: .color(Color(red: 0.68, green: 0.58, blue: 0.42).opacity(0.12))
            )
        }

        // Layer 4: Photorealistic rocks with 3D shading
        let rockPositions: [(CGFloat, CGFloat, CGFloat)] = [
            (50, 80, 8),
            (420, 150, 7),
            (200, 350, 9),
            (380, 420, 6),
            (120, 280, 5),
            (300, 100, 8),
            (150, 480, 7),
            (450, 320, 9),
            (90, 400, 6),
            (350, 80, 7)
        ]

        for (x, y, size) in rockPositions {
            // Rock shadow (soft, offset)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x + 1.5,
                    y: y + size * 0.6,
                    width: size * 1.2,
                    height: size * 0.4
                )),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.black.opacity(0.3),
                        Color.clear
                    ]),
                    center: CGPoint(x: x + size/2 + 1.5, y: y + size * 0.8),
                    startRadius: 0,
                    endRadius: size * 0.6
                )
            )

            // Rock body with gradient for 3D effect
            let rockPath = Path(ellipseIn: CGRect(x: x, y: y, width: size, height: size * 0.85))

            context.fill(
                rockPath,
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.60, green: 0.50, blue: 0.38),  // Light side
                        Color(red: 0.48, green: 0.38, blue: 0.28),  // Mid tone
                        Color(red: 0.35, green: 0.28, blue: 0.20)   // Shadow side
                    ]),
                    center: CGPoint(x: x + size * 0.3, y: y + size * 0.3),
                    startRadius: 0,
                    endRadius: size * 0.6
                )
            )

            // Rock highlight (sun reflection)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x + size * 0.2,
                    y: y + size * 0.15,
                    width: size * 0.3,
                    height: size * 0.25
                )),
                with: .color(Color(red: 0.75, green: 0.65, blue: 0.52).opacity(0.4))
            )

            // Rock texture (cracks and details)
            for _ in 0...2 {
                let crackX = x + CGFloat.random(in: size * 0.2...size * 0.8)
                let crackY = y + CGFloat.random(in: size * 0.2...size * 0.7)
                context.fill(
                    Path(ellipseIn: CGRect(x: crackX, y: crackY, width: 1, height: 1.5)),
                    with: .color(Color.black.opacity(0.4))
                )
            }
        }

        // Layer 5: Desert debris (small pebbles)
        for _ in 0..<25 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let pebbleSize = CGFloat.random(in: 1.5...3.5)

            context.fill(
                Path(ellipseIn: CGRect(
                    x: x,
                    y: y,
                    width: pebbleSize,
                    height: pebbleSize * 0.8
                )),
                with: .color(Color(red: 0.55, green: 0.45, blue: 0.35).opacity(0.5))
            )
        }

        // Layer 6: Enhanced cacti with more detail
        drawRealisticCactus(context: context, at: CGPoint(x: 30, y: 30), size: 14)
        drawRealisticCactus(context: context, at: CGPoint(x: 470, y: 450), size: 12)
        drawRealisticCactus(context: context, at: CGPoint(x: 250, y: 480), size: 11)
    }

    private func drawRealisticCactus(context: GraphicsContext, at position: CGPoint, size: CGFloat) {
        let cactusGreen = Color(red: 0.28, green: 0.52, blue: 0.28).opacity(0.65)
        let cactusHighlight = Color(red: 0.38, green: 0.62, blue: 0.38).opacity(0.5)
        let cactusShadow = Color(red: 0.18, green: 0.35, blue: 0.18).opacity(0.6)

        // Cactus shadow
        var shadowCtx = context
        shadowCtx.addFilter(.shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2))

        // Main trunk with gradient
        let trunkRect = CGRect(
            x: position.x - size/4,
            y: position.y,
            width: size/2,
            height: size
        )

        context.fill(
            Path(roundedRect: trunkRect, cornerRadius: size/7),
            with: .linearGradient(
                Gradient(colors: [cactusHighlight, cactusGreen, cactusShadow]),
                startPoint: CGPoint(x: trunkRect.minX, y: trunkRect.midY),
                endPoint: CGPoint(x: trunkRect.maxX, y: trunkRect.midY)
            )
        )

        // Left arm
        let leftArmRect = CGRect(
            x: position.x - size/2,
            y: position.y + size/3,
            width: size/3,
            height: size/2.5
        )
        context.fill(
            Path(roundedRect: leftArmRect, cornerRadius: size/9),
            with: .linearGradient(
                Gradient(colors: [cactusHighlight, cactusGreen, cactusShadow]),
                startPoint: CGPoint(x: leftArmRect.minX, y: leftArmRect.midY),
                endPoint: CGPoint(x: leftArmRect.maxX, y: leftArmRect.midY)
            )
        )

        // Right arm
        let rightArmRect = CGRect(
            x: position.x + size/6,
            y: position.y + size/2.5,
            width: size/3,
            height: size/3
        )
        context.fill(
            Path(roundedRect: rightArmRect, cornerRadius: size/9),
            with: .linearGradient(
                Gradient(colors: [cactusHighlight, cactusGreen, cactusShadow]),
                startPoint: CGPoint(x: rightArmRect.minX, y: rightArmRect.midY),
                endPoint: CGPoint(x: rightArmRect.maxX, y: rightArmRect.midY)
            )
        )

        // Add spines (needles) for realism
        for i in 0..<5 {
            let spineY = position.y + CGFloat(i) * size / 5 + size / 10
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: position.x - size/8, y: spineY))
                    path.addLine(to: CGPoint(x: position.x - size/6, y: spineY))
                },
                with: .color(Color(red: 0.8, green: 0.75, blue: 0.6).opacity(0.6)),
                lineWidth: 0.5
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: position.x + size/8, y: spineY))
                    path.addLine(to: CGPoint(x: position.x + size/6, y: spineY))
                },
                with: .color(Color(red: 0.8, green: 0.75, blue: 0.6).opacity(0.6)),
                lineWidth: 0.5
            )
        }
    }

    private func drawApple(context: GraphicsContext, at position: Position) {
        let center = gridToScreen(position)
        let appleSize = GameConstants.cellSize - 4
        let rect = CGRect(
            x: center.x - appleSize / 2,
            y: center.y - appleSize / 2,
            width: appleSize,
            height: appleSize
        )

        // Ambient occlusion shadow (soft, large radius)
        var aoShadow = context
        aoShadow.addFilter(.shadow(color: .black.opacity(0.5), radius: 6, x: 1, y: 3))
        aoShadow.fill(
            Path(ellipseIn: rect),
            with: .color(.black.opacity(0.1))
        )

        // Base apple shape with complex gradient for spherical appearance
        let primaryGradient = Gradient(colors: [
            Color(red: 0.95, green: 0.25, blue: 0.20),  // Bright highlight
            Color(red: 0.85, green: 0.18, blue: 0.15),  // Mid red
            Color(red: 0.70, green: 0.12, blue: 0.10),  // Deep red
            Color(red: 0.55, green: 0.08, blue: 0.08),  // Shadow red
            Color(red: 0.40, green: 0.05, blue: 0.05)   // Dark core shadow
        ])

        // Main body with radial gradient from top-left (light source)
        let lightSource = CGPoint(x: center.x - appleSize * 0.25, y: center.y - appleSize * 0.25)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                primaryGradient,
                center: lightSource,
                startRadius: 0,
                endRadius: appleSize * 0.85
            )
        )

        // Add subtle color variation (natural apple texture)
        for _ in 0..<8 {
            let randomX = CGFloat.random(in: -appleSize/3...appleSize/3)
            let randomY = CGFloat.random(in: -appleSize/3...appleSize/3)
            let varSize = CGFloat.random(in: 3...6)

            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x + randomX - varSize/2,
                    y: center.y + randomY - varSize/2,
                    width: varSize,
                    height: varSize
                )),
                with: .color(Color(red: 0.75, green: 0.15, blue: 0.12).opacity(0.3))
            )
        }

        // Primary specular highlight (glossy surface reflection)
        let mainHighlight = CGRect(
            x: center.x - appleSize * 0.35,
            y: center.y - appleSize * 0.35,
            width: appleSize * 0.35,
            height: appleSize * 0.3
        )
        context.fill(
            Path(ellipseIn: mainHighlight),
            with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.75),
                    .white.opacity(0.35),
                    .clear
                ]),
                center: CGPoint(x: mainHighlight.midX, y: mainHighlight.midY),
                startRadius: 0,
                endRadius: appleSize * 0.25
            )
        )

        // Secondary diffuse highlight
        let secondaryHighlight = CGRect(
            x: center.x - appleSize * 0.15,
            y: center.y - appleSize * 0.20,
            width: appleSize * 0.20,
            height: appleSize * 0.18
        )
        context.fill(
            Path(ellipseIn: secondaryHighlight),
            with: .color(.white.opacity(0.25))
        )

        // Rim light on opposite side (reflected light)
        let rimLight = CGRect(
            x: center.x + appleSize * 0.20,
            y: center.y + appleSize * 0.15,
            width: appleSize * 0.15,
            height: appleSize * 0.25
        )
        context.fill(
            Path(ellipseIn: rimLight),
            with: .color(Color(red: 0.9, green: 0.4, blue: 0.3).opacity(0.3))
        )

        // Contact shadow at bottom (where apple touches surface)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - appleSize * 0.25,
                y: center.y + appleSize * 0.35,
                width: appleSize * 0.5,
                height: appleSize * 0.15
            )),
            with: .color(.black.opacity(0.4))
        )

        // Realistic stem with gradient
        let stemWidth: CGFloat = 2.5
        let stemHeight: CGFloat = 5
        let stemRect = CGRect(
            x: center.x - stemWidth / 2,
            y: center.y - appleSize / 2,
            width: stemWidth,
            height: stemHeight
        )

        // Stem shadow
        var stemShadowCtx = context
        stemShadowCtx.addFilter(.shadow(color: .black.opacity(0.5), radius: 2, x: 0.5, y: 0.5))
        stemShadowCtx.fill(
            Path(roundedRect: stemRect, cornerRadius: 1.2),
            with: .color(Color(red: 0.35, green: 0.20, blue: 0.12))
        )

        // Stem gradient
        context.fill(
            Path(roundedRect: stemRect, cornerRadius: 1.2),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.50, green: 0.30, blue: 0.18),
                    Color(red: 0.35, green: 0.20, blue: 0.12),
                    Color(red: 0.25, green: 0.15, blue: 0.08)
                ]),
                startPoint: CGPoint(x: stemRect.minX, y: stemRect.minY),
                endPoint: CGPoint(x: stemRect.maxX, y: stemRect.maxY)
            )
        )

        // Detailed leaf with veins
        let leafPath = Path { path in
            path.move(to: CGPoint(x: center.x + 2, y: center.y - appleSize / 2 + 1))
            path.addQuadCurve(
                to: CGPoint(x: center.x + 5, y: center.y - appleSize / 2 + 2),
                control: CGPoint(x: center.x + 4.5, y: center.y - appleSize / 2 - 0.5)
            )
            path.addQuadCurve(
                to: CGPoint(x: center.x + 2, y: center.y - appleSize / 2 + 3),
                control: CGPoint(x: center.x + 4, y: center.y - appleSize / 2 + 3.5)
            )
            path.closeSubpath()
        }

        // Leaf gradient
        context.fill(
            leafPath,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.35, green: 0.70, blue: 0.25),
                    Color(red: 0.25, green: 0.55, blue: 0.18),
                    Color(red: 0.18, green: 0.45, blue: 0.12)
                ]),
                startPoint: CGPoint(x: center.x + 2, y: center.y - appleSize / 2),
                endPoint: CGPoint(x: center.x + 5, y: center.y - appleSize / 2 + 3)
            )
        )

        // Leaf vein
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: center.x + 2.5, y: center.y - appleSize / 2 + 1.5))
                path.addLine(to: CGPoint(x: center.x + 4, y: center.y - appleSize / 2 + 2))
            },
            with: .color(Color(red: 0.15, green: 0.35, blue: 0.10).opacity(0.6)),
            lineWidth: 0.5
        )
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .snakeGame
    SnakeGameView(selectedTab: $selectedTab)
        .frame(width: 700, height: 800)
}
