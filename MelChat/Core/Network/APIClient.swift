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

    func uploadKeys(token: String, identityKey: String, signedPrekey: String, signedPrekeySignature: String) async throws {
        let endpoint = "\(baseURL)/auth/upload-keys"
        let body = UploadKeysRequest(
            identityKey: identityKey,
            signedPrekey: signedPrekey,
            signedPrekeySignature: signedPrekeySignature
        )
        let _: UploadKeysResponse = try await postWithAuth(endpoint: endpoint, body: body, token: token)
    }

    // MARK: - Keys Endpoints

    func uploadPublicKeys(token: String, bundle: PublicKeyBundle) async throws {
        let endpoint = "\(baseURL)/keys/upload"
        let body = UploadPublicKeysRequest(
            identityKey: bundle.identityKey,
            signedPrekey: bundle.signedPrekey,
            signedPrekeySignature: bundle.signedPrekeySignature,
            onetimePrekeys: bundle.onetimePrekeys
        )
        let _: KeyBundleResponse = try await postWithAuth(endpoint: endpoint, body: body, token: token)
    }

    func getUserPublicKeys(token: String, userId: String) async throws -> GetKeysResponse {
        let endpoint = "\(baseURL)/keys/user/\(userId)"
        return try await getWithAuth(endpoint: endpoint, token: token)
    }

    func getOwnPublicKeys(token: String) async throws -> GetKeysResponse {
        let endpoint = "\(baseURL)/keys/me"
        return try await getWithAuth(endpoint: endpoint, token: token)
    }

    func replenishPrekeys(token: String, prekeys: [String]) async throws {
        let endpoint = "\(baseURL)/keys/replenish"
        let body = ReplenishPrekeysRequest(prekeys: prekeys)
        let _: KeyBundleResponse = try await postWithAuth(endpoint: endpoint, body: body, token: token)
    }

    func getPrekeyCount(token: String) async throws -> Int {
        let endpoint = "\(baseURL)/keys/count"
        let response: PrekeyCountResponse = try await getWithAuth(endpoint: endpoint, token: token)
        return response.count
    }

    // MARK: - Messaging Endpoints

    func sendMessage(token: String, toUserId: String, encryptedPayload: String) async throws -> SendMessageResponse {
        let endpoint = "\(baseURL)/messages/send"
        let body = SendMessageRequest(toUserId: toUserId, encryptedPayload: encryptedPayload)
        return try await postWithAuth(endpoint: endpoint, body: body, token: token)
    }

    func getChats(token: String) async throws -> GetChatsResponse {
        let endpoint = "\(baseURL)/messages/chats"
        return try await getWithAuth(endpoint: endpoint, token: token)
    }

    func getChatMessages(token: String, otherUserId: String) async throws -> GetChatMessagesResponse {
        let endpoint = "\(baseURL)/messages/chat/\(otherUserId)"
        return try await getWithAuth(endpoint: endpoint, token: token)
    }

    func pollMessages(token: String) async throws -> PollMessagesResponse {
        let endpoint = "\(baseURL)/messages/poll"
        return try await getWithAuth(endpoint: endpoint, token: token)
    }

    func sendAck(token: String, messageId: String, status: String) async throws {
        let endpoint = "\(baseURL)/messages/ack"
        let body = SendAckRequest(messageId: messageId, status: status)
        let _: AckResponse = try await postWithAuth(endpoint: endpoint, body: body, token: token)
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

    private func postWithAuth<T: Decodable, B: Encodable>(
        endpoint: String,
        body: B,
        token: String
    ) async throws -> T {
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
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error ?? "Unknown error")
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func getWithAuth<T: Decodable>(
        endpoint: String,
        token: String
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            NetworkLogger.shared.log("❌ Invalid URL: \(endpoint)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Log request
        NetworkLogger.shared.log("🌐 GET \(endpoint)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            NetworkLogger.shared.log("❌ Invalid response from \(endpoint)")
            throw APIError.invalidResponse
        }

        // Log response
        NetworkLogger.shared.logResponse(httpResponse, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
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

struct SendMessageRequest: Codable {
    let toUserId: String
    let encryptedPayload: String
}

struct SendAckRequest: Codable {
    let messageId: String
    let status: String
}

// MARK: - Response Models

struct SendCodeResponse: Codable {
    let success: Bool
    let message: String
}

struct VerifyResponse: Codable {
    let success: Bool
    let token: String
    let user: UserResponse
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

struct SendMessageResponse: Codable {
    let success: Bool
    let messageId: String
    let status: String
}

struct ChatInfo: Codable, Identifiable {
    let userId: String
    let username: String
    let displayName: String?
    let isOnline: Bool
    let lastSeen: String?
    let lastMessageAt: String?
    let lastMessageStatus: String?
    
    // Identifiable conformance
    var id: String { userId }
}

struct GetChatsResponse: Codable {
    let success: Bool
    let chats: [ChatInfo]
}

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
    let payload: String
    let timestamp: String
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
        }
    }
}
