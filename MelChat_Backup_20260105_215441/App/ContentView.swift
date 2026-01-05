import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var showDebugMenu = false

    var body: some View {
        ZStack {
            if appState.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .onShake {
            showDebugMenu = true
        }
        .sheet(isPresented: $showDebugMenu) {
            NetworkLoggerView()
        }
        .task {
            // ⭐️ Configure MessageReceiver with SwiftData context on app launch
            if let userId = appState.currentUserId {
                MessageReceiver.shared.configure(
                    modelContext: modelContext,
                    currentUserId: userId
                )
                NetworkLogger.shared.log("✅ MessageReceiver configured in ContentView", group: "App")
            }
        }
        .onChange(of: appState.currentUserId) { _, newUserId in
            // Re-configure when user logs in
            if let userId = newUserId {
                MessageReceiver.shared.configure(
                    modelContext: modelContext,
                    currentUserId: userId
                )
                NetworkLogger.shared.log("✅ MessageReceiver re-configured after login", group: "App")
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ChatListView()
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

// MARK: - Shake Gesture Detection
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

struct ShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeViewModifier(action: action))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
