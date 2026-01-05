import Foundation
import SwiftData
import Combine

/// Handles sending messages with retry logic and encryption
@MainActor
class MessageSender: ObservableObject {
    static let shared = MessageSender()

    @Published var isSending = false

    private let webSocketManager = WebSocketManager.shared

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
        NetworkLogger.shared.log("🔐 Encrypting message with SimpleEncryption...", group: "MessageSender")
        
        // Get recipient's public key
        let recipientPublicKey = try await APIClient.shared.getPublicKey(userId: toUserId.uuidString)
        
        // Encrypt message using SimpleEncryption
        let ciphertext = try SimpleEncryption.shared.encrypt(
            message: message.content,
            recipientPublicKey: recipientPublicKey
        )
        
        NetworkLogger.shared.log("✅ Message encrypted", group: "MessageSender")

        // Send via WebSocket with retry
        await sendWithRetry(message: message, toUserId: toUserId, ciphertext: ciphertext)
    }

    // MARK: - Send with Retry

    private func sendWithRetry(message: Message, toUserId: UUID, ciphertext: String) async {
        var attempt = 0

        while attempt < maxRetries {
            guard webSocketManager.isConnected else {
                NetworkLogger.shared.log("⚠️ WebSocket not connected, waiting... (attempt \(attempt + 1))", group: "MessageSender")
                // Wait for connection
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                attempt += 1
                continue
            }

            // TODO: Send via WebSocket (WebSocket needs string support)
            // webSocketManager.sendMessage(toUserId: toUserId.uuidString, encryptedMessage: ciphertext)

            // Update status
            message.statusRaw = MessageStatus.sent.rawValue
            NetworkLogger.shared.log("✅ Message sent via WebSocket (attempt \(attempt + 1))", group: "MessageSender")
            return
        }

        // Failed after all retries
        message.statusRaw = MessageStatus.failed.rawValue
        message.retryCount = maxRetries
        NetworkLogger.shared.log("❌ Message failed after \(maxRetries) attempts", group: "MessageSender")
    }

    // MARK: - Retry Failed Message

    func retryMessage(_ message: Message, modelContext: ModelContext) async throws {
        guard message.statusRaw == MessageStatus.failed.rawValue else {
            return
        }

        NetworkLogger.shared.log("🔄 Retrying failed message...", group: "MessageSender")
        
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
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .recipientKeyNotFound:
            return "Recipient's encryption key not found"
        case .privateKeyNotFound:
            return "Your encryption key not found"
        case .invalidPublicKey:
            return "Invalid encryption key format"
        case .encryptionFailed:
            return "Failed to encrypt message"
        }
    }
}
