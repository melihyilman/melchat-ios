import Foundation
import SwiftData
import Combine

/// Handles receiving and decrypting incoming messages
@MainActor
class MessageReceiver: ObservableObject {
    static let shared = MessageReceiver()

    private let encryptionService = EncryptionService()
    private let webSocketManager = WebSocketManager.shared
    private let keychainHelper = KeychainHelper()
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
            // Get private key for decryption
            guard let privateKeyData = try? keychainHelper.load(forKey: KeychainHelper.Keys.privateKey) else {
                print("❌ Private key not found for decryption")
                return
            }

            // Decrypt payload
            let decryptedContent = try decryptMessage(
                encryptedPayload: receivedMessage.payload,
                privateKey: privateKeyData
            )

            // Save to database
            await saveMessage(
                id: receivedMessage.id,
                fromUserId: receivedMessage.from,
                toUserId: receivedMessage.to,
                content: decryptedContent,
                timestamp: receivedMessage.timestamp
            )

            // Send ACK
            webSocketManager.sendAck(messageId: receivedMessage.id, status: "delivered")

            print("✅ Message received and decrypted")

        } catch {
            print("❌ Failed to handle received message: \(error)")
            // Send failed ACK
            webSocketManager.sendAck(messageId: receivedMessage.id, status: "failed")
        }
    }

    // MARK: - Decrypt Message

    private func decryptMessage(encryptedPayload: String, privateKey: Data) throws -> String {
        // Parse encrypted payload from base64 JSON
        guard let payloadData = encryptedPayload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: String],
              let ephemeralPublicKeyBase64 = json["ephemeralPublicKey"],
              let ciphertextBase64 = json["ciphertext"],
              let ephemeralPublicKey = Data(base64Encoded: ephemeralPublicKeyBase64),
              let ciphertext = Data(base64Encoded: ciphertextBase64) else {
            throw MessageReceiverError.invalidPayload
        }

        let encryptedMessage = EncryptedMessage(
            ciphertext: ciphertext,
            ephemeralPublicKey: ephemeralPublicKey
        )

        // Decrypt (using dummy sender public key - TODO: get from backend)
        let decryptedContent = try encryptionService.decrypt(
            encryptedMessage: encryptedMessage,
            recipientPrivateKey: privateKey,
            senderPublicKey: ephemeralPublicKey
        )

        return decryptedContent
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
            print("❌ Invalid UUID format in message")
            return
        }
        
        // TODO: Get or create chat with SwiftData ModelContext
        // For now, just create a chat ID from the two user IDs
        let chatId = UUID() // Temporary - should lookup or create proper chat
        
        // TODO: Save to SwiftData
        // let message = Message(
        //     id: messageId,
        //     content: content,
        //     senderId: senderId,
        //     recipientId: recipientId,
        //     chatId: chatId,
        //     contentType: .text,
        //     status: .delivered,
        //     isFromCurrentUser: false
        // )
        // modelContext.insert(message)
        
        print("💾 Saving message: \(content.prefix(50))...")
    }

    // MARK: - Process Offline Messages

    func processOfflineMessages(_ messages: [[String: Any]], modelContext: ModelContext) async {
        for messageDict in messages {
            guard let id = messageDict["id"] as? String,
                  let from = messageDict["from"] as? String,
                  let to = messageDict["to"] as? String,
                  let payload = messageDict["payload"] as? String,
                  let timestamp = messageDict["timestamp"] as? String else {
                continue
            }

            let receivedMessage = ReceivedMessage(
                id: id,
                from: from,
                to: to,
                payload: payload,
                timestamp: timestamp
            )

            await handleReceivedMessage(receivedMessage)
        }
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
