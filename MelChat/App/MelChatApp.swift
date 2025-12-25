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
            // TODO: Validate token with backend
            // For now, assume valid and extract userId
            isAuthenticated = true
            // TODO: Extract userId from JWT token
        } else {
            isAuthenticated = false
        }
    }

    func login(userId: UUID, token: String) {
        // Save auth token to Keychain
        if let tokenData = token.data(using: .utf8) {
            try? keychainHelper.save(tokenData, forKey: KeychainHelper.Keys.authToken)
        }

        currentUserId = userId
        isAuthenticated = true

        // Connect WebSocket (convert UUID to String for backend)
        webSocketManager.connect(userId: userId.uuidString)
    }

    func logout() {
        // Disconnect WebSocket
        webSocketManager.disconnect()

        // Clear Keychain
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.authToken)
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.privateKey)
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.publicKey)

        currentUserId = nil
        isAuthenticated = false
    }
}
