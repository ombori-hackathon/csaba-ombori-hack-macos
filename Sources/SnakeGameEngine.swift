import Foundation
import Combine

class SnakeGameEngine: ObservableObject {
    @Published var snake: Snake
    @Published var mouse: Position
    @Published var score: Int = 0
    @Published var gameState: GameState = .ready
    @Published var currentSpeed: TimeInterval
    @Published var godMode: Bool = false

    private var currentDirection: Direction = .right
    var mouseDirection: Direction = .right  // Public for rendering
    private var mouseTickCounter: Int = 0

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
        self.mouse = Position(x: 0, y: 0)
        spawnMouse()
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
        mouseTickCounter = 0
        spawnMouse()
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

        // Update mouse position (50% speed - every 2 ticks)
        updateMousePosition()

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

        // Check mouse collision
        var newBody = [newHead] + snake.body
        if newHead == mouse {
            // Snake grows, keep tail
            score += GameConstants.scorePerFood
            increaseSpeed()
            spawnMouse()
        } else {
            // Remove tail (snake moves without growing)
            newBody.removeLast()
        }

        snake.body = newBody
    }

    // MARK: - Mouse Management

    private func spawnMouse() {
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
            mouse = randomPosition
            // Initialize random starting direction for Brownian motion
            mouseDirection = [Direction.up, .down, .left, .right].randomElement()!
        }
    }

    private func updateMousePosition() {
        // Move mouse every 2 ticks (50% speed)
        mouseTickCounter += 1
        if mouseTickCounter < 2 {
            return
        }
        mouseTickCounter = 0

        // Brownian motion: 70% chance to continue, 30% chance to change direction
        if Double.random(in: 0...1) > 0.7 {
            // Pick random new direction
            mouseDirection = [Direction.up, .down, .left, .right].randomElement()!
        }

        // Calculate new position
        let newPosition = mouse.move(in: mouseDirection)

        // Handle wall collision - mouse always bounces (even in god mode)
        if newPosition.x < 0 || newPosition.x >= GameConstants.gridSize ||
           newPosition.y < 0 || newPosition.y >= GameConstants.gridSize {
            // Bounce back - reverse direction
            mouseDirection = mouseDirection.opposite
            return
        }

        // Optional: Simple snake avoidance (don't move into snake body)
        if snake.contains(newPosition) {
            // Try a random different direction
            mouseDirection = [Direction.up, .down, .left, .right].randomElement()!
            return
        }

        // Update mouse position
        mouse = newPosition
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
