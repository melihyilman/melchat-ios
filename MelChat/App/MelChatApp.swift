import SwiftUI
import SwiftData
import Combine
import UIKit

@main
struct MelChatApp: App {
    @StateObject private var appState = AppState()

    // SwiftData container
    let modelContainer: ModelContainer

    init() {
        do {
            // Configure ModelContainer with schema
            let schema = Schema([
                User.self,
                Message.self,
                Chat.self,
                Group.self
            ])

            // TEMPORARY: Use in-memory storage to avoid migration issues during development
            // Change to isStoredInMemoryOnly: false for production
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            print("✅ SwiftData ModelContainer initialized successfully (in-memory mode)")
        } catch {
            print("❌ SwiftData Error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserId: UUID?

    private let webSocketManager = WebSocketManager.shared
    private let messageReceiver = MessageReceiver.shared
    private let keychainHelper = KeychainHelper()

    init() {
        checkAuthStatus()
    }

    private func checkAuthStatus() {
        // Check Keychain for auth token
        if let tokenData = try? keychainHelper.load(forKey: KeychainHelper.Keys.authToken),
           let token = String(data: tokenData, encoding: .utf8),
           !token.isEmpty {
            // Load userId from UserDefaults
            if let userIdString = UserDefaults.standard.string(forKey: "currentUserId"),
               let userId = UUID(uuidString: userIdString) {
                currentUserId = userId
                isAuthenticated = true
                
                // Reconnect WebSocket
                webSocketManager.connect(userId: userId.uuidString)
                
                print("✅ Restored session for user: \(userId)")
            } else {
                // Token exists but no userId - force re-login
                isAuthenticated = false
                try? keychainHelper.delete(forKey: KeychainHelper.Keys.authToken)
            }
        } else {
            isAuthenticated = false
        }
    }

    func login(userId: UUID, token: String) {
        // Save auth token to Keychain
        if let tokenData = token.data(using: .utf8) {
            try? keychainHelper.save(tokenData, forKey: KeychainHelper.Keys.authToken)
        }
        
        // Save userId to UserDefaults
        UserDefaults.standard.set(userId.uuidString, forKey: "currentUserId")

        currentUserId = userId
        isAuthenticated = true

        // Connect WebSocket (convert UUID to String for backend)
        webSocketManager.connect(userId: userId.uuidString)
        
        print("✅ User logged in: \(userId)")
    }

    func logout() {
        // Disconnect WebSocket
        webSocketManager.disconnect()

        // Clear auth token (but keep encryption keys!)
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.authToken)
        
        // NOTE: We do NOT delete encryption keys
        // They are tied to the user account and should persist
        // try? keychainHelper.delete(forKey: KeychainHelper.Keys.privateKey)
        // try? keychainHelper.delete(forKey: KeychainHelper.Keys.publicKey)
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "displayName")
        UserDefaults.standard.removeObject(forKey: "email")

        currentUserId = nil
        isAuthenticated = false
        
        print("✅ User logged out (encryption keys preserved)")
    }
}
