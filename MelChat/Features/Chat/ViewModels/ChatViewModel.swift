import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    let otherUserId: String
    let otherUserName: String

    init(otherUserId: String, otherUserName: String) {
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
    }

    // MARK: - Load Messages

    func loadMessages() async {
        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.getChatMessages(token: token, otherUserId: otherUserId)
            NetworkLogger.shared.log("✅ Loaded \(response.messages.count) messages")

            // TODO: Load from SwiftData and decrypt
            // For now, just log the metadata
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Error loading messages: \(error)")
        }

        isLoading = false
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }
        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            return
        }

        isSending = true
        errorMessage = nil

        do {
            // 1. Encrypt message with E2E encryption
            let encryptedMessage = try await EncryptionManager.shared.encrypt(
                message: text,
                for: otherUserId,
                token: token
            )

            // 2. Send to backend (convert ciphertext Data to base64 String)
            let response = try await APIClient.shared.sendMessage(
                token: token,
                toUserId: otherUserId,
                encryptedPayload: encryptedMessage.ciphertext.base64EncodedString()
            )

            NetworkLogger.shared.log("✅ Message sent (encrypted): \(response.messageId)")

            // 3. Add to local messages (optimistic UI)
            // TODO: Get proper senderId and chatId from app state
            let currentUserId = UUID() // Replace with actual current user ID
            let chatId = UUID() // Replace with actual chat ID
            
            // Convert String messageId to UUID
            guard let messageUUID = UUID(uuidString: response.messageId) else {
                NetworkLogger.shared.log("⚠️ Invalid message ID format: \(response.messageId)")
                isSending = false
                return
            }
            
            let newMessage = Message(
                id: messageUUID,
                content: text, // Store decrypted locally
                senderId: currentUserId,
                recipientId: UUID(uuidString: otherUserId) ?? UUID(),
                chatId: chatId,
                contentType: .text,
                status: .sent,
                isFromCurrentUser: true,
                timestamp: Date()
            )
            messages.append(newMessage)

            // Success haptic
            HapticManager.shared.success()

        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Error sending message: \(error)")
            HapticManager.shared.error()
        }

        isSending = false
    }

    // MARK: - Helpers

    private func getToken() -> String? {
        // Get token from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }
}
