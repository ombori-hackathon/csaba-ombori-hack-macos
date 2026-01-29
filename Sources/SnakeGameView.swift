import SwiftUI
import AppKit

struct SnakeGameView: View {
    @StateObject private var engine = SnakeGameEngine()
    @State private var keyMonitor: Any?
    @State private var showNamePrompt = false
    @State private var playerName = ""
    @State private var isSubmittingScore = false
    @State private var submissionError: String?
    @State private var showSubmissionError = false
    @State private var showSubmissionSuccess = false

    var body: some View {
        VStack(spacing: 20) {
            // Header with score and status
            HStack {
                Text("Snake Game")
                    .font(.title.bold())
                Spacer()
                Text("Score: \(engine.score)")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.green)
            }
            .padding(.horizontal)

            // Game board
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.black)
                    .frame(width: GameConstants.boardSize, height: GameConstants.boardSize)
                    .border(Color.gray, width: 2)

                // Game canvas
                Canvas { context, size in
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

                    // Draw food
                    let foodRect = CGRect(
                        x: CGFloat(engine.food.x) * GameConstants.cellSize,
                        y: CGFloat(engine.food.y) * GameConstants.cellSize,
                        width: GameConstants.cellSize,
                        height: GameConstants.cellSize
                    )
                    context.fill(
                        Path(ellipseIn: foodRect.insetBy(dx: 2, dy: 2)),
                        with: .color(.red)
                    )

                    // Draw snake
                    for (index, segment) in engine.snake.body.enumerated() {
                        let rect = CGRect(
                            x: CGFloat(segment.x) * GameConstants.cellSize,
                            y: CGFloat(segment.y) * GameConstants.cellSize,
                            width: GameConstants.cellSize,
                            height: GameConstants.cellSize
                        )

                        // Head is brighter green
                        let color: Color = index == 0 ? .green : Color(red: 0, green: 0.8, blue: 0)

                        context.fill(
                            Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3),
                            with: .color(color)
                        )
                    }
                }
                .frame(width: GameConstants.boardSize, height: GameConstants.boardSize)

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
                                    .disabled(engine.score == 0)

                                    Button("Play Again") {
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
            }
            Button("Play Again") {
                showSubmissionSuccess = false
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
        case 1: // S key
            engine.changeDirection(.down)
        case 0: // A key
            engine.changeDirection(.left)
        case 2: // D key
            engine.changeDirection(.right)
        case 49: // Space bar
            handleSpaceBar()
        default:
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
}

#Preview {
    SnakeGameView()
        .frame(width: 700, height: 800)
}
