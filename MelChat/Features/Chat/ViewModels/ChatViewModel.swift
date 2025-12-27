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
    
    // SwiftData context for persistence
    private var modelContext: ModelContext?
    private var currentUserId: UUID?
    private var chatId: UUID?
    
    // Notification observer
    private var cancellables = Set<AnyCancellable>()

    init(otherUserId: String, otherUserName: String) {
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        
        // Listen for new messages
        setupNotificationListener()
    }
    
    // Setup notification listener for new messages
    private func setupNotificationListener() {
        NotificationCenter.default.publisher(for: NSNotification.Name("NewMessageReceived"))
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let notificationChatId = userInfo["chatId"] as? String,
                      let message = userInfo["message"] as? Message,
                      let myChatId = self.chatId?.uuidString,
                      notificationChatId == myChatId else {
                    return
                }
                
                // Add message to UI if not already there
                Task { @MainActor in
                    if !self.messages.contains(where: { $0.id == message.id }) {
                        self.messages.append(message)
                        NetworkLogger.shared.log("✅ New message added to chat UI")
                        HapticManager.shared.light()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Configure with SwiftData context and user info
    func configure(modelContext: ModelContext, currentUserId: UUID, chatId: UUID) {
        self.modelContext = modelContext
        self.currentUserId = currentUserId
        self.chatId = chatId
        
        // Load messages from local DB
        Task {
            await loadMessagesFromLocalDB()
        }
    }

    // MARK: - Load Messages
    
    /// Load messages from local SwiftData database
    private func loadMessagesFromLocalDB() async {
        guard let modelContext = modelContext,
              let chatId = chatId else {
            NetworkLogger.shared.log("⚠️ ModelContext or chatId not configured")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate { $0.chatId == chatId },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            
            let fetchedMessages = try modelContext.fetch(descriptor)
            messages = fetchedMessages
            
            NetworkLogger.shared.log("✅ Loaded \(messages.count) messages from local DB")
        } catch {
            NetworkLogger.shared.log("❌ Error loading from SwiftData: \(error)")
        }
    }

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

            // 3. Save to local SwiftData (with proper IDs)
            guard let currentUserId = currentUserId,
                  let chatId = chatId,
                  let modelContext = modelContext else {
                NetworkLogger.shared.log("⚠️ Missing context for saving message")
                isSending = false
                return
            }
            
            // Convert String messageId to UUID
            guard let messageUUID = UUID(uuidString: response.messageId) else {
                NetworkLogger.shared.log("⚠️ Invalid message ID format: \(response.messageId)")
                isSending = false
                return
            }
            
            guard let recipientUUID = UUID(uuidString: otherUserId) else {
                NetworkLogger.shared.log("⚠️ Invalid recipient ID format: \(otherUserId)")
                isSending = false
                return
            }
            
            let newMessage = Message(
                id: messageUUID,
                content: text, // Store decrypted locally
                senderId: currentUserId,
                recipientId: recipientUUID,
                chatId: chatId,
                contentType: .text,
                status: .sent,
                isFromCurrentUser: true,
                timestamp: Date()
            )
            
            // Save to SwiftData
            modelContext.insert(newMessage)
            try modelContext.save()
            
            // Add to UI
            messages.append(newMessage)
            
            NetworkLogger.shared.log("💾 Message saved to local DB")

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
