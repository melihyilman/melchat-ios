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
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Listen for force logout notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceLogout"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NetworkLogger.shared.log("🚨 Force logout triggered - invalid refresh token", group: "Auth")
            self?.logout()
        }
    }

    private func checkAuthStatus() {
        // ⭐️ Check TokenManager for access token
        Task {
            do {
                let token = try await TokenManager.shared.getAccessToken()
                if !token.isEmpty {
                    NetworkLogger.shared.log("✅ Valid token found, user is authenticated", group: "Auth")
                    isAuthenticated = true
                    
                    // ✅ Extract userId from JWT token payload
                    if let userId = extractUserIdFromJWT(token) {
                        currentUserId = userId
                        NetworkLogger.shared.log("✅ Extracted userId from token: \(userId.uuidString)", group: "Auth")
                        
                        // Connect WebSocket
                        webSocketManager.connect(userId: userId.uuidString)
                    } else {
                        NetworkLogger.shared.log("⚠️ Failed to extract userId from JWT", group: "Auth")
                    }
                } else {
                    isAuthenticated = false
                }
            } catch {
                NetworkLogger.shared.log("❌ No valid token found: \(error)", group: "Auth")
                isAuthenticated = false
            }
        }
    }
    
    /// Extract userId from JWT token
    private func extractUserIdFromJWT(_ token: String) -> UUID? {
        // JWT format: header.payload.signature
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            NetworkLogger.shared.log("❌ Invalid JWT format", group: "Auth")
            return nil
        }
        
        // Decode base64 payload (part 1)
        let payloadBase64 = parts[1]
        
        // Add padding if needed (base64 requires padding)
        var base64 = payloadBase64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let payloadData = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let userIdString = json["userId"] as? String,
              let userId = UUID(uuidString: userIdString) else {
            NetworkLogger.shared.log("❌ Failed to decode JWT payload", group: "Auth")
            return nil
        }
        
        return userId
    }

    func login(userId: UUID) {
        // Token already saved by AuthViewModel via TokenManager
        // Just update app state
        currentUserId = userId
        isAuthenticated = true

        NetworkLogger.shared.log("✅ AppState.login() called with userId: \(userId.uuidString)", group: "Auth")
        NetworkLogger.shared.log("✅ currentUserId set to: \(currentUserId?.uuidString ?? "nil")", group: "Auth")

        // Connect WebSocket (convert UUID to String for backend)
        webSocketManager.connect(userId: userId.uuidString)
        
        NetworkLogger.shared.log("✅ User logged in: \(userId.uuidString)", group: "Auth")
    }

    func logout() {
        NetworkLogger.shared.log("🚪 Starting logout process...", group: "Auth")
        
        // Disconnect WebSocket
        webSocketManager.disconnect()

        // ⭐️ Clear tokens via TokenManager
        Task { @MainActor in
            do {
                try await TokenManager.shared.logout()
                NetworkLogger.shared.log("✅ User logged out", group: "Auth")
            } catch {
                NetworkLogger.shared.log("⚠️ Logout error: \(error)", group: "Auth")
                // Still clear local tokens
                TokenManager.shared.clearTokens()
            }
            
            // Clear encryption keys
            try? keychainHelper.delete(forKey: KeychainHelper.Keys.privateKey)
            try? keychainHelper.delete(forKey: KeychainHelper.Keys.publicKey)

            // Update state
            currentUserId = nil
            isAuthenticated = false
            
            NetworkLogger.shared.log("✅ Logout complete - returning to login screen", group: "Auth")
        }
    }
}
