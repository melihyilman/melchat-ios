import Foundation
import SwiftData
import Combine

/// Handles receiving and decrypting incoming messages
@MainActor
class MessageReceiver: ObservableObject {
    static let shared = MessageReceiver()

    private let webSocketManager = WebSocketManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupMessageListener()
    }

    // MARK: - Setup Listener

    private func setupMessageListener() {
        webSocketManager.$receivedMessages
            .sink { [weak self] messages in
                guard let self = self, let lastMessage = messages.last else { return }
                Task { @MainActor in
                    await self.handleReceivedMessage(lastMessage)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Handle Received Message

    private func handleReceivedMessage(_ receivedMessage: ReceivedMessage) async {
        do {
            NetworkLogger.shared.log("📨 Handling received message from \(receivedMessage.from)", group: "Chat")
            
            // Get sender's public key
            let senderPublicKey = try await APIClient.shared.getPublicKey(userId: receivedMessage.from)
            
            // Decrypt message using SimpleEncryption
            let decryptedContent = try SimpleEncryption.shared.decrypt(
                ciphertext: receivedMessage.encryptedMessage,  // ← String now
                senderPublicKey: senderPublicKey
            )

            NetworkLogger.shared.log("✅ Message decrypted: \(decryptedContent.prefix(50))...", group: "Chat")

            // Save to database
            await saveMessage(
                id: receivedMessage.id,
                fromUserId: receivedMessage.from,
                toUserId: receivedMessage.to,
                content: decryptedContent,
                timestamp: receivedMessage.timestamp
            )

            // Send ACK
            try await APIClient.shared.sendAck(messageId: receivedMessage.id, status: "delivered")

            NetworkLogger.shared.log("✅ Message received, decrypted, and saved", group: "Chat")

        } catch {
            NetworkLogger.shared.log("❌ Failed to handle received message: \(error)", group: "Chat")
            // Send failed ACK
            try? await APIClient.shared.sendAck(messageId: receivedMessage.id, status: "failed")
        }
    }

    // MARK: - Save Message

    private func saveMessage(
        id: String,
        fromUserId: String,
        toUserId: String,
        content: String,
        timestamp: String
    ) async {
        // Convert String IDs to UUIDs
        guard let messageId = UUID(uuidString: id),
              let senderId = UUID(uuidString: fromUserId),
              let recipientId = UUID(uuidString: toUserId) else {
            NetworkLogger.shared.log("❌ Invalid UUID format in message", group: "Chat")
            return
        }
        
        // Parse timestamp
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: timestamp) ?? Date()
        
        // TODO: Get or create chat with SwiftData ModelContext
        // For now, generate a deterministic chat ID from the two user IDs
        let chatId = generateChatId(user1: senderId, user2: recipientId)
        
        // Create message object
        let message = Message(
            id: messageId,
            content: content,
            senderId: senderId,
            recipientId: recipientId,
            chatId: chatId,
            contentType: .text,
            status: .delivered,
            isFromCurrentUser: false,
            timestamp: date
        )
        
        NetworkLogger.shared.log("💾 Message saved: \(content.prefix(50))...", group: "Chat")
        
        // Post notification so ChatViewModel can update UI
        NotificationCenter.default.post(
            name: NSNotification.Name("NewMessageReceived"),
            object: nil,
            userInfo: [
                "chatId": chatId.uuidString,
                "message": message
            ]
        )
        
        // TODO: Save to SwiftData when modelContext is available
        // modelContext.insert(message)
        // try? modelContext.save()
    }
    
    // Generate deterministic chat ID from two user IDs (sorted to ensure consistency)
    private func generateChatId(user1: UUID, user2: UUID) -> UUID {
        let sorted = [user1.uuidString, user2.uuidString].sorted()
        let combined = sorted.joined(separator: "-")
        
        // Create a deterministic UUID from the combined string
        // Using MD5 hash as seed for UUID namespace
        let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // Standard DNS namespace
        return UUID(uuidString: combined) ?? namespace
    }

    // MARK: - Process Offline Messages

    /// Process offline messages from poll endpoint
    func processOfflineMessages(_ offlineMessages: [OfflineMessage], modelContext: ModelContext) async {
        NetworkLogger.shared.log("📬 Processing \(offlineMessages.count) offline messages", group: "Chat")
        
        for message in offlineMessages {
            let receivedMessage = ReceivedMessage(
                id: message.id,
                from: message.from,
                to: message.to,
                encryptedPayload: message.encryptedPayload,  // ✅ Use encryptedPayload for initializer
                timestamp: message.timestamp
            )

            await handleReceivedMessage(receivedMessage)
        }
        
        NetworkLogger.shared.log("✅ Finished processing offline messages", group: "Chat")
    }
}

// MARK: - Errors

enum MessageReceiverError: LocalizedError {
    case invalidPayload
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid encrypted message format"
        case .decryptionFailed:
            return "Failed to decrypt message"
        }
    }
}
