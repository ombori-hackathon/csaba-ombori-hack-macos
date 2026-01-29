import SwiftUI

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Snake Game Leaderboard")
                    .font(.title.bold())
                Spacer()
                Button {
                    Task {
                        await loadLeaderboard()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            .padding(.horizontal)

            // Content
            if isLoading && entries.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading leaderboard...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("No scores yet")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Be the first to set a high score!")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Leaderboard table
                Table(entries) {
                    TableColumn("Rank") { entry in
                        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                            HStack {
                                Text("\(index + 1)")
                                    .font(.headline.monospacedDigit())
                                if index < 3 {
                                    Image(systemName: rankIcon(for: index))
                                        .foregroundStyle(rankColor(for: index))
                                }
                            }
                        }
                    }
                    .width(min: 70, ideal: 80, max: 100)

                    TableColumn("Player") { entry in
                        Text(entry.player_name)
                            .font(.body)
                    }
                    .width(min: 150, ideal: 200, max: 300)

                    TableColumn("Score") { entry in
                        Text("\(entry.score)")
                            .font(.body.monospacedDigit().bold())
                            .foregroundStyle(.green)
                    }
                    .width(min: 80, ideal: 100, max: 120)

                    TableColumn("Date") { entry in
                        Text(formatDate(entry.timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 150, ideal: 180, max: 200)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Entry count
                Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if isLoading && !entries.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                            .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .alert("Error Loading Leaderboard", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
            Button("Retry") {
                Task {
                    await loadLeaderboard()
                }
            }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            await loadLeaderboard()
        }
    }

    // MARK: - Helper Functions

    private func loadLeaderboard() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedEntries = try await APIClient.shared.fetchLeaderboard(limit: 100)
            entries = fetchedEntries
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func rankIcon(for index: Int) -> String {
        switch index {
        case 0: return "medal.fill"
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        default: return ""
        }
    }

    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .brown
        default: return .secondary
        }
    }
}

#Preview {
    LeaderboardView()
        .frame(width: 700, height: 500)
}
