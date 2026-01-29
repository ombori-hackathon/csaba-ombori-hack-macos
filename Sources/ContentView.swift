import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SnakeGameView()
                .tabItem {
                    Label("Snake Game", systemImage: "gamecontroller.fill")
                }

            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy.fill")
                }

            APIDemoView()
                .tabItem {
                    Label("API Demo", systemImage: "network")
                }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
