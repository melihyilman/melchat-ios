import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
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
