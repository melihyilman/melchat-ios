import Foundation

// MARK: - API Client
class APIClient {
    static let shared = APIClient()

    // Simulator için localhost çalışır, gerçek cihaz için Mac'in IP'sini kullan
    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:3000/api"
    #else
    private let baseURL = "http://192.168.1.116:3000/api" // TODO: Mac'in gerçek IP'sini buraya yaz
    #endif
    
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        
        // Network logging
        NetworkLogger.shared.log("🌐 API Client initialized - Base URL: \(baseURL)")
    }

    // MARK: - Auth Endpoints

    func sendVerificationCode(email: String) async throws -> SendCodeResponse {
        let endpoint = "\(baseURL)/auth/send-code"
        let body = SendCodeRequest(email: email)
        return try await post(endpoint: endpoint, body: body)
    }

    func verifyCode(email: String, code: String, username: String? = nil, displayName: String? = nil) async throws -> VerifyResponse {
        let endpoint = "\(baseURL)/auth/verify"
        let body = VerifyRequest(
            email: email,
            code: code,
            username: username,
            displayName: displayName
        )
        return try await post(endpoint: endpoint, body: body)
    }

    // ⭐️ SIMPLE E2E - Upload single public key
    func uploadPublicKey(publicKey: String) async throws {
        let endpoint = "\(baseURL)/keys/upload"
        let body = ["publicKey": publicKey]
        let _: UploadKeysResponse = try await postWithAuth(endpoint: endpoint, body: body)
        NetworkLogger.shared.log("✅ Public key uploaded", group: "Encryption")
    }
    
    // ⭐️ SIMPLE E2E - Get user's public key
    func getPublicKey(userId: String) async throws -> String {
        let endpoint = "\(baseURL)/keys/\(userId)"
        let response: GetPublicKeyResponse = try await getWithAuth(endpoint: endpoint)
        return response.publicKey
    }
    
    // Upload Signal Protocol public key bundle (DEPRECATED - use uploadPublicKey)
    func uploadSignalKeys(bundle: PublicKeyBundle) async throws {
        let endpoint = "\(baseURL)/keys/upload"
        
        // Convert OneTimePrekey to OneTimePrekeyData
        let prekeyData = bundle.oneTimePrekeys.map { prekey in
            OneTimePrekeyData(id: prekey.id, publicKey: prekey.publicKey)
        }
        
        let body = UploadSignalKeysRequest(
            identityKey: bundle.identityKey,  // ✅ Ed25519 only
            signedPrekey: bundle.signedPrekey,
            signedPrekeySignature: bundle.signedPrekeySignature,
            oneTimePrekeys: prekeyData
        )
        let _: UploadKeysResponse = try await postWithAuth(endpoint: endpoint, body: body)
    }
    
    // Legacy endpoint (deprecated)
    func uploadKeys(identityKey: String, signedPrekey: String, signedPrekeySignature: String) async throws {
        let endpoint = "\(baseURL)/auth/upload-keys"
        let body = UploadKeysRequest(
            identityKey: identityKey,
            signedPrekey: signedPrekey,
            signedPrekeySignature: signedPrekeySignature
        )
        let _: UploadKeysResponse = try await postWithAuth(endpoint: endpoint, body: body)
    }

    // MARK: - Keys Endpoints

    func uploadPublicKeys(bundle: PublicKeyBundle) async throws {
        let endpoint = "\(baseURL)/keys/upload"
        let body = UploadPublicKeysRequest(
            identityKey: bundle.identityKey,
            signedPrekey: bundle.signedPrekey,
            signedPrekeySignature: bundle.signedPrekeySignature,
            onetimePrekeys: bundle.oneTimePrekeys.map { $0.publicKey }
        )
        let _: KeyBundleResponse = try await postWithAuth(endpoint: endpoint, body: body)
    }

    func getUserPublicKeys(userId: String) async throws -> GetKeysResponse {
        let endpoint = "\(baseURL)/keys/user/\(userId)"
        return try await getWithAuth(endpoint: endpoint)
    }

    func getOwnPublicKeys() async throws -> GetKeysResponse {
        let endpoint = "\(baseURL)/keys/me"
        return try await getWithAuth(endpoint: endpoint)
    }

    func replenishPrekeys(prekeys: [String]) async throws {
        let endpoint = "\(baseURL)/keys/replenish"
        let body = ReplenishPrekeysRequest(prekeys: prekeys)
        let _: KeyBundleResponse = try await postWithAuth(endpoint: endpoint, body: body)
    }

    func getPrekeyCount() async throws -> Int {
        let endpoint = "\(baseURL)/keys/count"
        let response: PrekeyCountResponse = try await getWithAuth(endpoint: endpoint)
        return response.count
    }

    // MARK: - Messaging Endpoints

    // ⭐️ SIMPLE E2E - Send encrypted message (STRING ciphertext)
    func sendEncryptedMessage(toUserId: String, encryptedMessage: String) async throws -> SendMessageResponse {
        let endpoint = "\(baseURL)/messages/send"
        
        struct SimpleEncryptedRequest: Codable {
            let toUserId: String
            let encryptedPayload: String  // ⚠️ String, not object
        }
        
        let body = SimpleEncryptedRequest(toUserId: toUserId, encryptedPayload: encryptedMessage)
        return try await postWithAuth(endpoint: endpoint, body: body)
    }
    
    // DEPRECATED - Old Signal Protocol version (uses object)
    func sendEncryptedMessageOld(toUserId: String, encryptedPayload: EncryptedPayload) async throws -> SendMessageResponse {
        let endpoint = "\(baseURL)/messages/send"
        let body = SendMessageRequest(toUserId: toUserId, encryptedPayload: encryptedPayload)
        return try await postWithAuth(endpoint: endpoint, body: body)
    }
    
    // DEPRECATED - Use sendEncryptedMessage
    func sendMessage(toUserId: String, encryptedPayload: EncryptedPayload) async throws -> SendMessageResponse {
        let endpoint = "\(baseURL)/messages/send"
        let body = SendMessageRequest(toUserId: toUserId, encryptedPayload: encryptedPayload)
        return try await postWithAuth(endpoint: endpoint, body: body)
    }

    func getChats() async throws -> GetChatsResponse {
        let endpoint = "\(baseURL)/messages/chats"
        return try await getWithAuth(endpoint: endpoint)
    }

    func getChatMessages(otherUserId: String) async throws -> GetChatMessagesResponse {
        let endpoint = "\(baseURL)/messages/chat/\(otherUserId)"
        return try await getWithAuth(endpoint: endpoint)
    }

    func pollMessages() async throws -> PollMessagesResponse {
        let endpoint = "\(baseURL)/messages/poll"
        return try await getWithAuth(endpoint: endpoint)
    }

    func sendAck(messageId: String, status: String) async throws {
        let endpoint = "\(baseURL)/messages/ack"
        let body = SendAckRequest(messageId: messageId, status: status)
        let _: AckResponse = try await postWithAuth(endpoint: endpoint, body: body)
    }
    
    // MARK: - User Search
    
    func searchUsers(query: String) async throws -> SearchUsersResponse {
        let endpoint = "\(baseURL)/users/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        return try await getWithAuth(endpoint: endpoint)
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken(refreshToken: String) async throws -> RefreshTokenResponse {
        let endpoint = "\(baseURL)/auth/refresh"
        let body = RefreshTokenRequest(refreshToken: refreshToken)
        return try await post(endpoint: endpoint, body: body)
    }
    
    func logout(refreshToken: String) async throws {
        let endpoint = "\(baseURL)/auth/logout"
        let body = RefreshTokenRequest(refreshToken: refreshToken)
        let _: LogoutResponse = try await post(endpoint: endpoint, body: body)
    }
    
    func logoutAll(refreshToken: String) async throws {
        let endpoint = "\(baseURL)/auth/logout-all"
        let body = RefreshTokenRequest(refreshToken: refreshToken)
        let _: LogoutResponse = try await post(endpoint: endpoint, body: body)
    }

    // MARK: - Generic Requests

    private func post<T: Decodable, B: Encodable>(
        endpoint: String,
        body: B
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            NetworkLogger.shared.log("❌ Invalid URL: \(endpoint)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        // Log request
        NetworkLogger.shared.logRequest(request, body: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            NetworkLogger.shared.log("❌ Invalid response from \(endpoint)")
            throw APIError.invalidResponse
        }

        // Log response
        NetworkLogger.shared.logResponse(httpResponse, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Unknown error")
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // ⭐️ POST with automatic token handling
    private func postWithAuth<T: Decodable, B: Encodable>(
        endpoint: String,
        body: B
    ) async throws -> T {
        // Get token from TokenManager (with auto-refresh if needed)
        let token = try await TokenManager.shared.getAccessToken()
        
        guard let url = URL(string: endpoint) else {
            NetworkLogger.shared.log("❌ Invalid URL: \(endpoint)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        // Log request
        NetworkLogger.shared.logRequest(request, body: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            NetworkLogger.shared.log("❌ Invalid response from \(endpoint)")
            throw APIError.invalidResponse
        }

        // Log response
        NetworkLogger.shared.logResponse(httpResponse, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            // ⭐️ Handle 401 Unauthorized with auto-refresh
            if httpResponse.statusCode == 401 {
                NetworkLogger.shared.log("❌ 401 Unauthorized - Attempting token refresh...", group: "Auth")
                
                // Try to refresh token once
                do {
                    let newToken = try await TokenManager.shared.refreshAccessToken()
                    NetworkLogger.shared.log("✅ Token refreshed, retrying request...", group: "Auth")
                    
                    // Retry request with new token
                    request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, retryResponse) = try await session.data(for: request)
                    
                    guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                        throw APIError.invalidResponse
                    }
                    
                    NetworkLogger.shared.logResponse(retryHttpResponse, data: retryData)
                    
                    guard (200...299).contains(retryHttpResponse.statusCode) else {
                        throw APIError.httpError(retryHttpResponse.statusCode)
                    }
                    
                    return try JSONDecoder().decode(T.self, from: retryData)
                    
                } catch {
                    NetworkLogger.shared.log("❌ Token refresh failed, user must re-login", group: "Auth")
                    
                    // ⭐️ Post notification to force logout
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("ForceLogout"), object: nil)
                    }
                    
                    throw APIError.unauthorized
                }
            }
            
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Unknown error")
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // ⭐️ GET with automatic token handling
    private func getWithAuth<T: Decodable>(
        endpoint: String
    ) async throws -> T {
        // Get token from TokenManager (with auto-refresh if needed)
        let token = try await TokenManager.shared.getAccessToken()
        
        guard let url = URL(string: endpoint) else {
            NetworkLogger.shared.log("❌ Invalid URL: \(endpoint)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // ⭐️ FIX: Log request with headers (not just URL)
        NetworkLogger.shared.logRequest(request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            NetworkLogger.shared.log("❌ Invalid response from \(endpoint)")
            throw APIError.invalidResponse
        }

        // Log response
        NetworkLogger.shared.logResponse(httpResponse, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            // ⭐️ Handle 401 Unauthorized with auto-refresh
            if httpResponse.statusCode == 401 {
                NetworkLogger.shared.log("❌ 401 Unauthorized - Attempting token refresh...", group: "Auth")
                
                // Try to refresh token once
                do {
                    let newToken = try await TokenManager.shared.refreshAccessToken()
                    NetworkLogger.shared.log("✅ Token refreshed, retrying request...", group: "Auth")
                    
                    // Retry request with new token
                    request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                    let (retryData, retryResponse) = try await session.data(for: request)
                    
                    guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                        throw APIError.invalidResponse
                    }
                    
                    NetworkLogger.shared.logResponse(retryHttpResponse, data: retryData)
                    
                    guard (200...299).contains(retryHttpResponse.statusCode) else {
                        throw APIError.httpError(retryHttpResponse.statusCode)
                    }
                    
                    return try JSONDecoder().decode(T.self, from: retryData)
                    
                } catch {
                    NetworkLogger.shared.log("❌ Token refresh failed, user must re-login", group: "Auth")
                    
                    // ⭐️ Post notification to force logout
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("ForceLogout"), object: nil)
                    }
                    
                    throw APIError.unauthorized
                }
            }
            
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Unknown error")
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Request Models

struct SendCodeRequest: Codable {
    let email: String
}

struct VerifyRequest: Codable {
    let email: String
    let code: String
    let username: String?
    let displayName: String?
}

struct UploadKeysRequest: Codable {
    let identityKey: String
    let signedPrekey: String
    let signedPrekeySignature: String
}

struct UploadSignalKeysRequest: Codable {
    let identityKey: String  // ✅ Ed25519 (for signature verification)
    let signedPrekey: String
    let signedPrekeySignature: String
    let oneTimePrekeys: [OneTimePrekeyData]
}

struct OneTimePrekeyData: Codable {
    let id: String
    let publicKey: String // Base64
}

struct EncryptedPayload: Codable {
    let ciphertext: String
    let ratchetPublicKey: String
    let chainLength: Int
    let previousChainLength: Int
}

struct SendMessageRequest: Codable {
    let toUserId: String
    let encryptedPayload: EncryptedPayload
}

struct SendAckRequest: Codable {
    let messageId: String
    let status: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

// MARK: - Response Models

struct SendCodeResponse: Codable {
    let success: Bool
    let message: String
}

struct VerifyResponse: Codable {
    let success: Bool
    let token: String?            // ⚠️ Deprecated - Use accessToken
    let accessToken: String?      // ⭐️ NEW: Access token
    let refreshToken: String?     // ⭐️ NEW: Refresh token
    let expiresIn: Int?           // ⭐️ NEW: Expiration in seconds
    let user: UserResponse
    
    // Helper to get access token (backward compatible)
    var finalAccessToken: String {
        accessToken ?? token ?? ""
    }
}

struct UserResponse: Codable {
    let id: String
    let username: String
    let displayName: String?
    let isNewUser: Bool
}

struct UploadKeysResponse: Codable {
    let success: Bool
    let message: String
}

struct GetPublicKeyResponse: Codable {
    let userId: String
    let username: String
    let publicKey: String
}

struct SendMessageResponse: Codable {
    let success: Bool
    let messageId: String
    let status: String
}

struct RefreshTokenResponse: Codable {
    let success: Bool
    let accessToken: String
    let expiresIn: Int
}

struct LogoutResponse: Codable {
    let success: Bool
    let message: String
}

struct ChatInfo: Codable, Identifiable, Hashable {
    let userId: String
    let username: String
    let displayName: String?
    let isOnline: Bool
    let lastSeen: String?
    
    // ⭐️ NEW: Rich chat metadata
    let lastMessage: String?           // Last message preview
    let lastMessageAt: String?         // ISO timestamp
    let lastMessageStatus: String?     // "sent", "delivered", "read"
    let unreadCount: Int?              // Number of unread messages
    let lastMessageFromMe: Bool?       // Did I send the last message?
    
    // Identifiable conformance
    var id: String { userId }
    
    // Hashable conformance (for NavigationStack)
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
    }
    
    static func == (lhs: ChatInfo, rhs: ChatInfo) -> Bool {
        lhs.userId == rhs.userId
    }
    
    // Helper computed properties
    var displayNameOrUsername: String {
        displayName ?? username
    }
    
    var formattedLastSeen: String? {
        guard let lastSeen = lastSeen else { return nil }
        
        // Parse ISO date
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: lastSeen) else { return lastSeen }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
    
    var formattedLastMessageTime: String? {
        guard let lastMessageAt = lastMessageAt else { return nil }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: lastMessageAt) else { return nil }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Check if today
        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        }
        
        // Check if yesterday
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        
        // Check if this week
        let components = calendar.dateComponents([.day], from: date, to: now)
        if let days = components.day, days < 7 {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE" // Monday, Tuesday, etc.
            return weekdayFormatter.string(from: date)
        }
        
        // Older: show date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yy"
        return dateFormatter.string(from: date)
    }
}

struct GetChatsResponse: Codable {
    let success: Bool
    let chats: [ChatInfo]
}

// MARK: - User Search

struct UserSearchResult: Codable, Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let isOnline: Bool
    let lastSeen: String?
}

struct SearchUsersResponse: Codable {
    let success: Bool?  // ⭐️ Optional - backend may not return this
    let users: [UserSearchResult]
    
    // Custom decoder to handle both formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode success, default to true if not present
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success)
        
        // Decode users - this is required
        self.users = try container.decode([UserSearchResult].self, forKey: .users)
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case users
    }
}

// MARK: - Message Metadata

struct MessageMetadata: Codable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let status: String
    let queuedAt: String
    let contentType: String
}

struct GetChatMessagesResponse: Codable {
    let success: Bool
    let messages: [MessageMetadata]
}

struct OfflineMessage: Codable {
    let id: String
    let from: String
    let to: String
    let encryptedPayload: String  // ✅ Backend sends "encryptedPayload"
    let timestamp: String
    
    // Map to encryptedMessage for internal use
    var encryptedMessage: String {
        return encryptedPayload
    }
}

struct PollMessagesResponse: Codable {
    let success: Bool
    let messages: [OfflineMessage]
}

struct AckResponse: Codable {
    let success: Bool
}

struct ErrorResponse: Codable {
    let success: Bool?
    let error: String?
}

// MARK: - Keys Requests/Responses

struct UploadPublicKeysRequest: Codable {
    let identityKey: String
    let signedPrekey: String
    let signedPrekeySignature: String
    let onetimePrekeys: [String]
}

struct GetKeysResponse: Codable {
    let success: Bool
    let keys: PublicKeyInfo
}

struct PublicKeyInfo: Codable {
    let userId: String
    let username: String
    let identityKey: String
    let signedPrekey: String
    let signedPrekeySignature: String
    let onetimePrekey: String?
}

struct KeyBundleResponse: Codable {
    let success: Bool
    let message: String?
}

struct ReplenishPrekeysRequest: Codable {
    let prekeys: [String]
}

struct PrekeyCountResponse: Codable {
    let success: Bool
    let count: Int
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    case unauthorized  // ⭐️ Session expired / Invalid token

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Your session has expired. Please login again."
        }
    }
}
