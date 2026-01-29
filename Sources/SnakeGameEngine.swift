import Foundation
import Combine

class SnakeGameEngine: ObservableObject {
    @Published var snake: Snake
    @Published var food: Position
    @Published var score: Int = 0
    @Published var gameState: GameState = .ready
    @Published var currentSpeed: TimeInterval
    @Published var godMode: Bool = false

    private var currentDirection: Direction = .right

    var currentVisualDirection: Direction {
        guard snake.body.count >= 2 else { return currentDirection }
        let head = snake.body[0]
        let neck = snake.body[1]

        if head.x > neck.x { return .right }
        if head.x < neck.x { return .left }
        if head.y > neck.y { return .down }
        if head.y < neck.y { return .up }

        return currentDirection
    }
    private var directionQueue: [Direction] = []
    private var timer: Timer?

    init() {
        // Initialize snake at center of grid, length 3, facing right
        let centerX = GameConstants.gridSize / 2
        let centerY = GameConstants.gridSize / 2
        self.snake = Snake(body: [
            Position(x: centerX, y: centerY),
            Position(x: centerX - 1, y: centerY),
            Position(x: centerX - 2, y: centerY)
        ])
        self.currentSpeed = GameConstants.initialSpeed
        self.food = Position(x: 0, y: 0)
        spawnFood()
    }

    // MARK: - Game Control

    func startGame() {
        guard gameState == .ready else { return }
        gameState = .playing
        startTimer()
    }

    func pauseGame() {
        guard gameState == .playing else { return }
        gameState = .paused
        stopTimer()
    }

    func resumeGame() {
        guard gameState == .paused else { return }
        gameState = .playing
        startTimer()
    }

    func resetGame() {
        stopTimer()

        // Reset snake
        let centerX = GameConstants.gridSize / 2
        let centerY = GameConstants.gridSize / 2
        snake = Snake(body: [
            Position(x: centerX, y: centerY),
            Position(x: centerX - 1, y: centerY),
            Position(x: centerX - 2, y: centerY)
        ])

        // Reset game state
        currentDirection = .right
        directionQueue = []
        score = 0
        currentSpeed = GameConstants.initialSpeed
        gameState = .ready
        godMode = false
        spawnFood()
    }

    func toggleGodMode() {
        godMode.toggle()
    }

    // MARK: - Direction Control

    func changeDirection(_ newDirection: Direction) {
        guard gameState == .playing else { return }

        // Get the last direction in queue, or current direction if queue is empty
        let lastDirection = directionQueue.last ?? currentDirection

        // Prevent 180-degree turns
        if newDirection != lastDirection.opposite {
            // Only queue if different from last direction
            if newDirection != lastDirection {
                directionQueue.append(newDirection)
                // Limit queue size to prevent excessive queuing
                if directionQueue.count > 2 {
                    directionQueue.removeFirst()
                }
            }
        }
    }

    // MARK: - Game Loop

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: currentSpeed, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard gameState == .playing else { return }

        // Process direction queue
        if !directionQueue.isEmpty {
            currentDirection = directionQueue.removeFirst()
        }

        // Calculate new head position
        var newHead = snake.head.move(in: currentDirection)

        // Handle wall collision
        if newHead.x < 0 || newHead.x >= GameConstants.gridSize ||
           newHead.y < 0 || newHead.y >= GameConstants.gridSize {
            if godMode {
                // Wrap around walls in god mode
                newHead = Position(
                    x: (newHead.x + GameConstants.gridSize) % GameConstants.gridSize,
                    y: (newHead.y + GameConstants.gridSize) % GameConstants.gridSize
                )
            } else {
                endGame()
                return
            }
        }

        // Check self collision (always active, even in god mode)
        if snake.contains(newHead) {
            endGame()
            return
        }

        // Check food collision
        var newBody = [newHead] + snake.body
        if newHead == food {
            // Snake grows, keep tail
            score += GameConstants.scorePerFood
            increaseSpeed()
            spawnFood()
        } else {
            // Remove tail (snake moves without growing)
            newBody.removeLast()
        }

        snake.body = newBody
    }

    // MARK: - Food Management

    private func spawnFood() {
        var validPositions: [Position] = []

        for x in 0..<GameConstants.gridSize {
            for y in 0..<GameConstants.gridSize {
                let pos = Position(x: x, y: y)
                if !snake.contains(pos) {
                    validPositions.append(pos)
                }
            }
        }

        if let randomPosition = validPositions.randomElement() {
            food = randomPosition
        }
    }

    // MARK: - Speed Management

    private func increaseSpeed() {
        let newSpeed = currentSpeed - GameConstants.speedDecrement
        if newSpeed >= GameConstants.maxSpeed {
            currentSpeed = newSpeed
            // Restart timer with new speed
            if gameState == .playing {
                startTimer()
            }
        } else {
            currentSpeed = GameConstants.maxSpeed
        }
    }

    // MARK: - Game Over

    private func endGame() {
        stopTimer()
        gameState = .gameOver
    }

    deinit {
        stopTimer()
    }
}
