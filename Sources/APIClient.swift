import Foundation

// MARK: - API Client

@MainActor
class APIClient {
    static let shared = APIClient()

    let baseURL = "http://localhost:8000"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    // MARK: - Leaderboard Endpoints

    func submitScore(playerName: String, score: Int) async throws -> LeaderboardEntry {
        let endpoint = "\(baseURL)/leaderboard"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = LeaderboardCreate(player_name: playerName, score: score)
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }

            let entry = try JSONDecoder().decode(LeaderboardEntry.self, from: data)
            return entry
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    func fetchLeaderboard(limit: Int = 100) async throws -> [LeaderboardEntry] {
        let endpoint = "\(baseURL)/leaderboard?limit=\(limit)"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }

            let leaderboardResponse = try JSONDecoder().decode(LeaderboardResponse.self, from: data)
            return leaderboardResponse.entries
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Health Check

    func checkHealth() async throws -> Bool {
        let endpoint = "\(baseURL)/health"

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        do {
            let (_, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            return (200...299).contains(httpResponse.statusCode)
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error (status code: \(statusCode))"
        case .networkError(let error):
            if (error as NSError).domain == NSURLErrorDomain {
                let code = (error as NSError).code
                switch code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                    return "No internet connection"
                case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                    return "Cannot connect to server. Make sure the API is running at http://localhost:8000"
                case NSURLErrorTimedOut:
                    return "Request timed out"
                default:
                    return "Network error: \(error.localizedDescription)"
                }
            }
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Request Models

struct LeaderboardCreate: Codable {
    let player_name: String
    let score: Int
}
