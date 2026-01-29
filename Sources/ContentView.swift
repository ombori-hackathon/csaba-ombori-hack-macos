import SwiftUI

enum AppTab {
    case snakeGame
    case leaderboard
    case apiDemo
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .snakeGame

    var body: some View {
        TabView(selection: $selectedTab) {
            SnakeGameView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Snake Game", systemImage: "gamecontroller.fill")
                }
                .tag(AppTab.snakeGame)

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy.fill")
                }
                .tag(AppTab.leaderboard)

            APIDemoView()
                .tabItem {
                    Label("API Demo", systemImage: "network")
                }
                .tag(AppTab.apiDemo)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
