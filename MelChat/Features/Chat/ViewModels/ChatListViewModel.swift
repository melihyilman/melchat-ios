import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class ChatListViewModel: ObservableObject {
    @Published var chats: [ChatInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 5.0 // 5 seconds
    
    // SwiftData context for saving messages
    private var modelContext: ModelContext?
    private var currentUserId: UUID?
    
    // Configure with SwiftData context
    func configure(modelContext: ModelContext, currentUserId: UUID) {
        self.modelContext = modelContext
        self.currentUserId = currentUserId
    }

    // MARK: - Load Chats

    func loadChats() async {
        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.getChats(token: token)
            chats = response.chats.sorted { ($0.lastMessageAt ?? "") > ($1.lastMessageAt ?? "") }
            NetworkLogger.shared.log("✅ Loaded \(chats.count) chats")
        } catch {
            errorMessage = "Failed to load chats: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Error loading chats: \(error)")
        }

        isLoading = false
    }

    // MARK: - Polling

    func startPolling() {
        stopPolling() // Stop any existing timer

        guard let token = getToken() else { return }

        NetworkLogger.shared.log("🔄 Starting message polling (every \(pollingInterval)s)")

        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollMessages()
            }
        }

        // Poll immediately
        Task {
            await pollMessages()
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        NetworkLogger.shared.log("⏸️ Stopped message polling")
    }

    private func pollMessages() async {
        guard let token = getToken() else { return }

        do {
            let response = try await APIClient.shared.pollMessages(token: token)

            if !response.messages.isEmpty {
                NetworkLogger.shared.log("📬 Received \(response.messages.count) new messages")

                // Process each message
                for message in response.messages {
                    await handleNewMessage(message)
                }

                // Reload chats to update UI
                await loadChats()
            }
        } catch {
            NetworkLogger.shared.log("⚠️ Polling error: \(error.localizedDescription)")
        }
    }

    private func handleNewMessage(_ message: OfflineMessage) async {
        guard let token = getToken() else { return }

        NetworkLogger.shared.log("📨 New message from \(message.from)")

        do {
            // 1. Decrypt message
            // Parse the encrypted payload (it should be base64 JSON with ephemeralPublicKey and ciphertext)
            guard let payloadData = message.payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: String],
                  let ephemeralPublicKeyBase64 = json["ephemeralPublicKey"],
                  let ciphertextBase64 = json["ciphertext"],
                  let ephemeralPublicKey = Data(base64Encoded: ephemeralPublicKeyBase64),
                  let ciphertext = Data(base64Encoded: ciphertextBase64) else {
                NetworkLogger.shared.log("❌ Invalid encrypted message format")
                return
            }
            
            let encryptedMsg = EncryptedMessage(
                ciphertext: ciphertext,
                ephemeralPublicKey: ephemeralPublicKey
            )

            let decryptedText = try await EncryptionManager.shared.decrypt(
                encryptedMessage: encryptedMsg,
                from: message.from,
                token: token
            )

            NetworkLogger.shared.log("🔓 Decrypted message: \(decryptedText)")

            // 2. Save to SwiftData
            guard let modelContext = modelContext,
                  let currentUserId = currentUserId else {
                NetworkLogger.shared.log("⚠️ ModelContext or currentUserId not configured")
                // Still send ACK even if save fails
                try? await APIClient.shared.sendAck(token: token, messageId: message.id, status: "delivered")
                return
            }
            
            // Convert String IDs to UUIDs
            guard let senderUUID = UUID(uuidString: message.from),
                  let messageUUID = UUID(uuidString: message.id) else {
                NetworkLogger.shared.log("⚠️ Invalid UUID format in message")
                return
            }
            
            // Generate deterministic chatId
            let chatId = generateChatId(userId1: currentUserId, userId2: senderUUID)
            
            // Create and save message
            let newMessage = Message(
                id: messageUUID,
                content: decryptedText,
                senderId: senderUUID,
                recipientId: currentUserId,
                chatId: chatId,
                contentType: .text,
                status: .delivered,
                isFromCurrentUser: false,
                timestamp: Date()
            )
            
            modelContext.insert(newMessage)
            try modelContext.save()
            
            NetworkLogger.shared.log("💾 Message saved to SwiftData")
            
            // Post notification for active chat view to refresh
            NotificationCenter.default.post(
                name: NSNotification.Name("NewMessageReceived"),
                object: nil,
                userInfo: ["chatId": chatId.uuidString, "message": newMessage]
            )

            // 3. Send ACK
            try await APIClient.shared.sendAck(token: token, messageId: message.id, status: "delivered")
            NetworkLogger.shared.log("✅ ACK sent for message \(message.id)")

            // Haptic feedback for new message
            HapticManager.shared.light()

        } catch {
            NetworkLogger.shared.log("❌ Error handling message: \(error)")
            HapticManager.shared.error()
        }
    }

    // MARK: - Helpers
    
    // Generate deterministic chat ID from two user IDs (same as ChatViewModel)
    private func generateChatId(userId1: UUID, userId2: UUID) -> UUID {
        // Sort UUIDs to ensure same chatId regardless of order
        let sorted = [userId1, userId2].sorted { $0.uuidString < $1.uuidString }
        let combined = sorted[0].uuidString + sorted[1].uuidString
        
        // Generate deterministic UUID from combined string
        var hasher = Hasher()
        hasher.combine(combined)
        let hashValue = hasher.finalize()
        
        // Convert hash to UUID-like string
        let uuidString = String(format: "%08X-%04X-%04X-%04X-%012X",
                               (hashValue >> 96) & 0xFFFFFFFF,
                               (hashValue >> 80) & 0xFFFF,
                               (hashValue >> 64) & 0xFFFF,
                               (hashValue >> 48) & 0xFFFF,
                               hashValue & 0xFFFFFFFFFFFF)
        
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func getToken() -> String? {
        let keychainHelper = KeychainHelper()
        guard let tokenData = try? keychainHelper.load(forKey: KeychainHelper.Keys.authToken),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}
