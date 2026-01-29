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
        VStack(spacing: 20) {
            // Header with score and status
            HStack {
                Text("Snake Game")
                    .font(.title.bold())
                Spacer()
                if engine.godMode {
                    Label("GOD MODE", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.3), radius: 3, x: -2, y: -2)
                        .shadow(color: .yellow.opacity(0.3), radius: 3, x: 2, y: 2)
                }
                Text("Score: \(engine.score)")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: -2, y: -2)
                            .shadow(color: .white.opacity(0.1), radius: 4, x: 2, y: 2)
                    )
            }
            .padding(.horizontal)

            // Game board
            ZStack {
                // Background with neumorphic effect
                Rectangle()
                    .fill(Color.black)
                    .frame(width: GameConstants.boardSize, height: GameConstants.boardSize)
                    .shadow(color: Color.black.opacity(0.5), radius: 8, x: -4, y: -4)
                    .shadow(color: Color.white.opacity(0.1), radius: 8, x: 4, y: 4)
                    .border(Color.gray, width: 2)

                // Game canvas with 60fps animation
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        updateAnimationProgress(date: timeline.date)
                    // Draw grid lines (optional, for visual aid)
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
                        with: .color(.gray.opacity(0.2)),
                        lineWidth: 0.5
                    )

                    // Draw food (3D apple)
                    drawApple(context: context, at: engine.food)

                    // Draw snake with smooth interpolation
                    drawSnake(context: context)
                    }
                    .frame(width: GameConstants.boardSize, height: GameConstants.boardSize)
                }

                // Game state overlay
                if engine.gameState != .playing {
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: GameConstants.boardSize, height: GameConstants.boardSize)

                        VStack(spacing: 20) {
                            if engine.gameState == .ready {
                                Text("Ready to Play!")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.white)
                                Text("Use WASD Keys to move")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Press Space to start")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            } else if engine.gameState == .paused {
                                Text("Paused")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.yellow)
                                Text("Press Space to resume")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.8))
                            } else if engine.gameState == .gameOver {
                                Text("Game Over!")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(.red)
                                Text("Final Score: \(engine.score)")
                                    .font(.title.monospacedDigit())
                                    .foregroundStyle(.white)
                                HStack(spacing: 12) {
                                    Button("Submit Score") {
                                        showNamePrompt = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    .disabled(engine.score == 0 || scoreSubmitted)

                                    Button("Play Again") {
                                        scoreSubmitted = false
                                        godModeKeyCount = 0
                                        engine.resetGame()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                                }
                            }
                        }
                    }
                }
            }

            // Controls
            HStack(spacing: 20) {
                if engine.gameState == .ready {
                    Button("Start Game") {
                        engine.startGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.space, modifiers: [])
                } else if engine.gameState == .playing {
                    Button("Pause") {
                        engine.pauseGame()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.space, modifiers: [])
                } else if engine.gameState == .paused {
                    Button("Resume") {
                        engine.resumeGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.space, modifiers: [])
                }

                if engine.gameState != .ready {
                    Button("Reset") {
                        scoreSubmitted = false
                        godModeKeyCount = 0
                        engine.resetGame()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Instructions
            VStack(spacing: 8) {
                Text("Controls:")
                    .font(.headline)
                HStack(spacing: 20) {
                    Label("WASD: Move", systemImage: "keyboard")
                    Label("Space: Pause/Resume", systemImage: "space")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
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
        case 13: // W key
            engine.changeDirection(.up)
            godModeKeyCount = 0
        case 1: // S key
            engine.changeDirection(.down)
            godModeKeyCount = 0
        case 0: // A key
            engine.changeDirection(.left)
            godModeKeyCount = 0
        case 2: // D key
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

                let bodyColor = Color(red: 0, green: 0.7, blue: 0)

                // Neumorphic body segment
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 5),
                    with: .color(bodyColor)
                )

                // Inner shadow for depth effect
                var innerShadowContext = context
                innerShadowContext.addFilter(.shadow(color: .black.opacity(0.3), radius: 2, x: -1, y: -1))
                innerShadowContext.fill(
                    Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 4),
                    with: .color(bodyColor.opacity(0.1))
                )
            }
        }
    }

    private func drawSnakeHead(context: GraphicsContext, position: CGPoint, direction: Direction) {
        let headRadius = GameConstants.cellSize / 2 - 1
        let headRect = CGRect(
            x: position.x - headRadius,
            y: position.y - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        )

        // Head circle with neumorphic shadow
        let headColor = Color(red: 0, green: 0.9, blue: 0.1)

        // Outer glow
        var glowContext = context
        glowContext.addFilter(.shadow(color: .green.opacity(0.4), radius: 4, x: 0, y: 0))
        glowContext.fill(Path(ellipseIn: headRect), with: .color(headColor))

        // Main head
        context.fill(Path(ellipseIn: headRect), with: .color(headColor))

        // Inner shadow for depth
        var innerContext = context
        innerContext.addFilter(.shadow(color: .black.opacity(0.3), radius: 3, x: -2, y: -2))
        innerContext.fill(
            Path(ellipseIn: headRect.insetBy(dx: 2, dy: 2)),
            with: .color(headColor.opacity(0.1))
        )

        // Draw eyes based on direction
        let eyeOffset: (CGFloat, CGFloat) = {
            switch direction {
            case .up: return (0, -3)
            case .down: return (0, 3)
            case .left: return (-3, 0)
            case .right: return (3, 0)
            }
        }()

        // Determine eye positions based on direction
        let (leftEyeX, leftEyeY, rightEyeX, rightEyeY): (CGFloat, CGFloat, CGFloat, CGFloat)
        switch direction {
        case .up, .down:
            leftEyeX = position.x - 4
            rightEyeX = position.x + 4
            leftEyeY = position.y + eyeOffset.1
            rightEyeY = position.y + eyeOffset.1
        case .left, .right:
            leftEyeX = position.x + eyeOffset.0
            rightEyeX = position.x + eyeOffset.0
            leftEyeY = position.y - 4
            rightEyeY = position.y + 4
        }

        // Draw eyes
        let eyeSize: CGFloat = 3
        context.fill(
            Path(ellipseIn: CGRect(x: leftEyeX - eyeSize/2, y: leftEyeY - eyeSize/2, width: eyeSize, height: eyeSize)),
            with: .color(.black)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: rightEyeX - eyeSize/2, y: rightEyeY - eyeSize/2, width: eyeSize, height: eyeSize)),
            with: .color(.black)
        )

        // Eye highlights
        let highlightSize: CGFloat = 1
        context.fill(
            Path(ellipseIn: CGRect(x: leftEyeX - 0.5, y: leftEyeY - 1, width: highlightSize, height: highlightSize)),
            with: .color(.white.opacity(0.8))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: rightEyeX - 0.5, y: rightEyeY - 1, width: highlightSize, height: highlightSize)),
            with: .color(.white.opacity(0.8))
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
