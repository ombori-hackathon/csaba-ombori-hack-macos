import Foundation

struct Item: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let price: Double
}

struct HealthResponse: Codable {
    let status: String
}

// MARK: - Leaderboard Models

struct LeaderboardEntry: Codable, Identifiable {
    let id: Int
    let player_name: String
    let score: Int
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case player_name
        case score
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        player_name = try container.decode(String.self, forKey: .player_name)
        score = try container.decode(Int.self, forKey: .score)

        let timestampString = try container.decode(String.self, forKey: .timestamp)

        // Try parsing with fractional seconds first
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: timestampString) {
            timestamp = date
        } else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: timestampString) {
                timestamp = date
            } else {
                // Fallback: manually parse using DateFormatter for Python datetime format
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

                if let date = dateFormatter.date(from: timestampString) {
                    timestamp = date
                } else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .timestamp,
                        in: container,
                        debugDescription: "Date string '\(timestampString)' does not match expected format"
                    )
                }
            }
        }
    }
}

struct LeaderboardResponse: Codable {
    let entries: [LeaderboardEntry]
}
