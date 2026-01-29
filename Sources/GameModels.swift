import Foundation

// MARK: - Position

struct Position: Equatable, Hashable {
    let x: Int
    let y: Int

    func move(in direction: Direction) -> Position {
        switch direction {
        case .up:
            return Position(x: x, y: y - 1)
        case .down:
            return Position(x: x, y: y + 1)
        case .left:
            return Position(x: x - 1, y: y)
        case .right:
            return Position(x: x + 1, y: y)
        }
    }
}

// MARK: - Direction

enum Direction {
    case up, down, left, right

    var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

// MARK: - GameState

enum GameState {
    case ready
    case playing
    case paused
    case gameOver
}

// MARK: - Snake

struct Snake {
    var body: [Position]

    var head: Position {
        body.first!
    }

    func contains(_ position: Position) -> Bool {
        body.contains(position)
    }
}

// MARK: - Game Constants

enum GameConstants {
    static let gridSize = 20
    static let cellSize: CGFloat = 25
    static let initialSpeed: TimeInterval = 0.3 // 300ms
    static let maxSpeed: TimeInterval = 0.08 // 80ms
    static let speedDecrement: TimeInterval = 0.01 // 10ms
    static let scorePerFood = 10

    static var boardSize: CGFloat {
        CGFloat(gridSize) * cellSize
    }
}
