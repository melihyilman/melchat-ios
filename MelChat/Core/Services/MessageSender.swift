import Foundation
import SwiftData
import Combine

/// Handles sending messages with retry logic and encryption
@MainActor
class MessageSender: ObservableObject {
    static let shared = MessageSender()

    @Published var isSending = false

    private let encryptionService = EncryptionService()
    private let webSocketManager = WebSocketManager.shared
    private let keychainHelper = KeychainHelper()

    private let maxRetries = 3

    init() {}

    // MARK: - Send Message

    func sendMessage(
        content: String,
        toUserId: UUID,
        chatId: UUID,
        modelContext: ModelContext
    ) async throws {
        // Create message in database
        let message = Message(
            content: content,
            senderId: getCurrentUserId(),
            recipientId: toUserId,
            chatId: chatId,
            contentType: .text,
            status: .pending,
            isFromCurrentUser: true,
            timestamp: Date()
        )

        modelContext.insert(message)
        try modelContext.save()

        // Encrypt and send
        try await encryptAndSend(message: message, toUserId: toUserId)
    }

    // MARK: - Encrypt and Send

    private func encryptAndSend(message: Message, toUserId: UUID) async throws {
        // Get recipient's public key from backend
        guard let recipientPublicKey = try? await getRecipientPublicKey(toUserId) else {
            message.statusRaw = MessageStatus.failed.rawValue
            throw MessageError.recipientKeyNotFound
        }

        // Get sender's private key
        guard let privateKeyData = try? keychainHelper.load(forKey: KeychainHelper.Keys.privateKey) else {
            message.statusRaw = MessageStatus.failed.rawValue
            throw MessageError.privateKeyNotFound
        }

        // Encrypt message
        let encrypted = try encryptionService.encrypt(
            message: message.content,
            recipientPublicKey: recipientPublicKey,
            senderPrivateKey: privateKeyData
        )

        // Convert to base64 payload
        let payload = encrypted.toBase64()

        // Send via WebSocket with retry
        await sendWithRetry(message: message, toUserId: toUserId, payload: payload)
    }

    // MARK: - Send with Retry

    private func sendWithRetry(message: Message, toUserId: UUID, payload: String) async {
        var attempt = 0

        while attempt < maxRetries {
            guard webSocketManager.isConnected else {
                // Wait for connection
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                attempt += 1
                continue
            }

            // Send message (convert UUID to string for backend)
            webSocketManager.sendMessage(toUserId: toUserId.uuidString, encryptedPayload: payload)

            // Update status
            message.statusRaw = MessageStatus.sent.rawValue
            print("✅ Message sent (attempt \(attempt + 1))")
            return
        }

        // Failed after all retries
        message.statusRaw = MessageStatus.failed.rawValue
        message.retryCount = maxRetries
        print("❌ Message failed after \(maxRetries) attempts")
    }

    // MARK: - Get Recipient Public Key

    private func getRecipientPublicKey(_ userId: UUID) async throws -> Data {
        let url = URL(string: "http://localhost:3000/api/users/\(userId.uuidString)/keys")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct KeyResponse: Codable {
            let identityKey: String
        }

        let response = try JSONDecoder().decode(KeyResponse.self, from: data)
        guard let keyData = Data(base64Encoded: response.identityKey) else {
            throw MessageError.invalidPublicKey
        }

        return keyData
    }

    // MARK: - Retry Failed Message

    func retryMessage(_ message: Message, modelContext: ModelContext) async throws {
        guard message.statusRaw == MessageStatus.failed.rawValue else {
            return
        }

        message.statusRaw = MessageStatus.pending.rawValue
        message.retryCount = 0
        try modelContext.save()

        try await encryptAndSend(message: message, toUserId: message.recipientId)
    }

    // MARK: - Helpers

    private func getCurrentUserId() -> UUID {
        // TODO: Get from AppState or Keychain - for now return a default
        return UUID()
    }
}

// MARK: - Errors

enum MessageError: LocalizedError {
    case recipientKeyNotFound
    case privateKeyNotFound
    case invalidPublicKey

    var errorDescription: String? {
        switch self {
        case .recipientKeyNotFound:
            return "Recipient's encryption key not found"
        case .privateKeyNotFound:
            return "Your encryption key not found"
        case .invalidPublicKey:
            return "Invalid encryption key format"
        }
    }
}

// MARK: - Extensions

extension EncryptedMessage {
    func toBase64() -> String {
        let payload: [String: Any] = [
            "ephemeralPublicKey": ephemeralPublicKey.base64EncodedString(),
            "ciphertext": ciphertext.base64EncodedString()
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return ""
    }
}
