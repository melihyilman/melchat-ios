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
    
    // Notification observer & polling
    private var cancellables = Set<AnyCancellable>()
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 2.0 // Poll every 2 seconds in active chat

    init(otherUserId: String, otherUserName: String) {
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        
        // Listen for new messages
        setupNotificationListener()
    }
    
    deinit {
        // Don't call stopPolling() here - just invalidate timer directly
        pollingTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // Setup notification listener for new messages
    private func setupNotificationListener() {
        NotificationCenter.default.publisher(for: NSNotification.Name("NewMessageReceived"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                guard let userInfo = notification.userInfo,
                      let notificationChatId = userInfo["chatId"] as? String else {
                    NetworkLogger.shared.log("⚠️ Invalid notification userInfo", group: "Chat")
                    return
                }
                
                guard let myChatId = self.chatId?.uuidString else {
                    NetworkLogger.shared.log("⚠️ My chatId is nil", group: "Chat")
                    return
                }
                
                NetworkLogger.shared.log("📬 Notification received for chatId: \(notificationChatId), my chatId: \(myChatId)", group: "Chat")
                
                if notificationChatId == myChatId {
                    // Reload from SwiftData to get the new message
                    /*Task { [weak self] @MainActor in
                    guard let self else { return }
                    await self.reloadMessagesFromDB()
                    NetworkLogger.shared.log("✅ Reloaded messages after notification match", group: "Chat")
                    HapticManager.shared.light()
                    }*/
                } else {
                    NetworkLogger.shared.log("⚠️ ChatId mismatch, ignoring notification", group: "Chat")
                }
            }
            .store(in: &cancellables)
    }
    
    // Start polling for new messages (when chat is active)
    func startPolling() {
        stopPolling()
        
        NetworkLogger.shared.log("🔄 Starting chat polling (every \(pollingInterval)s)", group: "Chat")
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.reloadMessagesFromDB()
            }
        }
    }
    
    // Stop polling
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // Reload messages from SwiftData
    private func reloadMessagesFromDB() async {
        guard let modelContext = modelContext,
              let chatId = chatId else {
            return
        }
        
        do {
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate { $0.chatId == chatId },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            
            let fetchedMessages = try modelContext.fetch(descriptor)
            
            // Only update if there are new messages
            if fetchedMessages.count != messages.count {
                messages = fetchedMessages
                NetworkLogger.shared.log("📬 Updated chat view with \(messages.count) messages", group: "Chat")
            }
        } catch {
            NetworkLogger.shared.log("❌ Error reloading messages: \(error)", group: "Chat")
        }
    }
    
    // Configure with SwiftData context and user info
    func configure(modelContext: ModelContext, currentUserId: UUID, chatId: UUID) {
        self.modelContext = modelContext
        self.currentUserId = currentUserId
        self.chatId = chatId
        
        // Load messages from local DB
        Task { [weak self] in
            await self?.loadMessagesFromLocalDB()
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
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.getChatMessages(otherUserId: otherUserId)
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
        isSending = true
        errorMessage = nil

        do {
            // ⭐️ SIMPLE E2E - Get recipient's public key
            NetworkLogger.shared.log("🔑 Fetching recipient's public key...", group: "Chat")
            let recipientPublicKey = try await APIClient.shared.getPublicKey(userId: otherUserId)
            
            // ⭐️ SIMPLE E2E - Encrypt message
            NetworkLogger.shared.log("🔐 Encrypting message...", group: "Chat")
            let ciphertext = try SimpleEncryption.shared.encrypt(
                message: text,
                recipientPublicKey: recipientPublicKey
            )

            // Send to backend (as string)
            NetworkLogger.shared.log("📤 Sending encrypted message to backend...", group: "Chat")
            let response = try await APIClient.shared.sendEncryptedMessage(
                toUserId: otherUserId,
                encryptedMessage: ciphertext
            )

            NetworkLogger.shared.log("✅ Message sent (encrypted): \(response.messageId)", group: "Chat")

            // 3. Save to local SwiftData (with proper IDs)
            guard let currentUserId = currentUserId,
                  let chatId = chatId,
                  let modelContext = modelContext else {
                NetworkLogger.shared.log("⚠️ Missing context for saving message", group: "Chat")
                isSending = false
                return
            }
            
            // Convert String messageId to UUID
            guard let messageUUID = UUID(uuidString: response.messageId) else {
                NetworkLogger.shared.log("⚠️ Invalid message ID format: \(response.messageId)", group: "Chat")
                isSending = false
                return
            }
            
            guard let recipientUUID = UUID(uuidString: otherUserId) else {
                NetworkLogger.shared.log("⚠️ Invalid recipient ID format: \(otherUserId)", group: "Chat")
                isSending = false
                return
            }
            
            let newMessage = Message(
                id: messageUUID,
                content: text, // Store decrypted locally for quick access
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
            
            // Reload messages from DB to update UI immediately
            await reloadMessagesFromDB()
            
            NetworkLogger.shared.log("💾 Message saved to local DB and UI updated", group: "Chat")

            // Success haptic
            HapticManager.shared.success()

        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Error sending message: \(error)", group: "Chat")
            HapticManager.shared.error()
        }

        isSending = false
    }
}
