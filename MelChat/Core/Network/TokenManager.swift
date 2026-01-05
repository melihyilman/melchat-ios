import Foundation

/// Manages access and refresh tokens with automatic refresh capability
@MainActor
class TokenManager {
    static let shared = TokenManager()
    
    private let keychainHelper = KeychainHelper()
    
    // Keychain keys
    private enum Keys {
        static let accessToken = "com.melchat.accessToken"
        static let refreshToken = "com.melchat.refreshToken"
        static let tokenExpiresAt = "com.melchat.tokenExpiresAt"
    }
    
    private init() {}
    
    // MARK: - Save Tokens
    
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) throws {
        NetworkLogger.shared.log("💾 Saving tokens...", group: "Auth")
        
        // Save access token
        try keychainHelper.save(
            accessToken.data(using: .utf8)!,
            forKey: Keys.accessToken
        )
        
        // Save refresh token
        try keychainHelper.save(
            refreshToken.data(using: .utf8)!,
            forKey: Keys.refreshToken
        )
        
        // Calculate and save expiration date
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        let expiresAtString = ISO8601DateFormatter().string(from: expiresAt)
        try keychainHelper.save(
            expiresAtString.data(using: .utf8)!,
            forKey: Keys.tokenExpiresAt
        )
        
        NetworkLogger.shared.log("✅ Tokens saved (expires in \(expiresIn)s)", group: "Auth")
    }
    
    // MARK: - Get Access Token (with auto-refresh)
    
    func getAccessToken() async throws -> String {
        // Try to get current access token
        guard let accessTokenData = try? keychainHelper.load(forKey: Keys.accessToken),
              let accessToken = String(data: accessTokenData, encoding: .utf8) else {
            NetworkLogger.shared.log("❌ No access token found", group: "Auth")
            throw TokenError.noAccessToken
        }
        
        // Check if token is expired or about to expire (within 5 minutes)
        if isTokenExpiringSoon() {
            NetworkLogger.shared.log("⏰ Access token expiring soon, refreshing...", group: "Auth")
            return try await refreshAccessToken()
        }
        
        return accessToken
    }
    
    // MARK: - Get Refresh Token
    
    func getRefreshToken() throws -> String {
        guard let refreshTokenData = try? keychainHelper.load(forKey: Keys.refreshToken),
              let refreshToken = String(data: refreshTokenData, encoding: .utf8) else {
            NetworkLogger.shared.log("❌ No refresh token found", group: "Auth")
            throw TokenError.noRefreshToken
        }
        return refreshToken
    }
    
    // MARK: - Refresh Access Token
    
    func refreshAccessToken() async throws -> String {
        NetworkLogger.shared.log("🔄 Refreshing access token...", group: "Auth")
        
        let refreshToken = try getRefreshToken()
        
        do {
            let response = try await APIClient.shared.refreshAccessToken(refreshToken: refreshToken)
            
            // Save new access token
            try keychainHelper.save(
                response.accessToken.data(using: .utf8)!,
                forKey: Keys.accessToken
            )
            
            // Update expiration
            let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
            let expiresAtString = ISO8601DateFormatter().string(from: expiresAt)
            try keychainHelper.save(
                expiresAtString.data(using: .utf8)!,
                forKey: Keys.tokenExpiresAt
            )
            
            NetworkLogger.shared.log("✅ Access token refreshed", group: "Auth")
            return response.accessToken
            
        } catch {
            NetworkLogger.shared.log("❌ Token refresh failed: \(error)", group: "Auth")
            throw TokenError.refreshFailed
        }
    }
    
    // MARK: - Check Expiration
    
    func isTokenExpiringSoon(bufferSeconds: TimeInterval = 300) -> Bool {
        guard let expiresAtData = try? keychainHelper.load(forKey: Keys.tokenExpiresAt),
              let expiresAtString = String(data: expiresAtData, encoding: .utf8),
              let expiresAt = ISO8601DateFormatter().date(from: expiresAtString) else {
            return true // If we can't determine, assume expired
        }
        
        let now = Date()
        let bufferDate = now.addingTimeInterval(bufferSeconds)
        
        return expiresAt <= bufferDate
    }
    
    // MARK: - Clear Tokens
    
    func clearTokens() {
        NetworkLogger.shared.log("🗑️ Clearing all tokens", group: "Auth")
        
        try? keychainHelper.delete(forKey: Keys.accessToken)
        try? keychainHelper.delete(forKey: Keys.refreshToken)
        try? keychainHelper.delete(forKey: Keys.tokenExpiresAt)
    }
    
    // MARK: - Logout
    
    func logout() async throws {
        NetworkLogger.shared.log("👋 Logging out...", group: "Auth")
        
        do {
            let refreshToken = try getRefreshToken()
            try await APIClient.shared.logout(refreshToken: refreshToken)
            NetworkLogger.shared.log("✅ Logout successful", group: "Auth")
        } catch {
            NetworkLogger.shared.log("⚠️ Logout API failed, clearing local tokens anyway", group: "Auth")
        }
        
        clearTokens()
    }
    
    func logoutAll() async throws {
        NetworkLogger.shared.log("👋 Logging out from all devices...", group: "Auth")
        
        do {
            let refreshToken = try getRefreshToken()
            try await APIClient.shared.logoutAll(refreshToken: refreshToken)
            NetworkLogger.shared.log("✅ Logout all successful", group: "Auth")
        } catch {
            NetworkLogger.shared.log("⚠️ Logout all API failed, clearing local tokens anyway", group: "Auth")
        }
        
        clearTokens()
    }
}

// MARK: - Errors

enum TokenError: LocalizedError {
    case noAccessToken
    case noRefreshToken
    case refreshFailed
    
    var errorDescription: String? {
        switch self {
        case .noAccessToken:
            return "No access token found. Please login."
        case .noRefreshToken:
            return "No refresh token found. Please login."
        case .refreshFailed:
            return "Failed to refresh access token. Please login again."
        }
    }
}
