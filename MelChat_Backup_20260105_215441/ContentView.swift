import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                // Show main app interface
                ChatListView()
            } else {
                // Show login screen
                LoginView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(for: [User.self, Message.self, Chat.self, Group.self], inMemory: true)
}
