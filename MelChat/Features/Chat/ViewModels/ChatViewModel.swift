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
    @Published var showImagePicker = false

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
                        // Add with animation
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            self.messages.append(message)
                        }
                        
                        NetworkLogger.shared.log("✅ New message added to chat UI")
                        HapticManager.shared.light()
                        
                        // Play sound (optional)
                        // TODO: Add sound effect
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
            NetworkLogger.shared.log("⚠️ ModelContext or chatId not configured for loading", group: "Debug")
            return
        }
        
        NetworkLogger.shared.log("🔍 Loading messages with Chat ID: \(chatId)", group: "Debug")
        
        do {
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate { $0.chatId == chatId },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            
            let fetchedMessages = try modelContext.fetch(descriptor)
            messages = fetchedMessages
            
            NetworkLogger.shared.log("✅ Loaded \(messages.count) messages from local DB", group: "Debug")
            
            if messages.isEmpty {
                // Debug: Check if there are ANY messages in DB
                let allMessagesDescriptor = FetchDescriptor<Message>()
                let allMessages = try? modelContext.fetch(allMessagesDescriptor)
                NetworkLogger.shared.log("   Total messages in DB: \(allMessages?.count ?? 0)", group: "Debug")
                
                if let firstMessage = allMessages?.first {
                    NetworkLogger.shared.log("   First message chat ID: \(firstMessage.chatId)", group: "Debug")
                    NetworkLogger.shared.log("   Looking for chat ID: \(chatId)", group: "Debug")
                    NetworkLogger.shared.log("   IDs match: \(firstMessage.chatId == chatId)", group: "Debug")
                }
            }
        } catch {
            NetworkLogger.shared.log("❌ Error loading from SwiftData: \(error)", group: "Debug")
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
            // 1. ALWAYS load from local SwiftData first (instant UI)
            await loadMessagesFromLocalDB()
            
            NetworkLogger.shared.log("✅ Loaded \(messages.count) messages from local DB (will try backend sync)")

            // 2. Try to fetch from backend for sync (but backend only has metadata, no content!)
            // Skip this since backend /chat/:userId doesn't return message content
            // Backend only stores metadata in PostgreSQL, actual encrypted messages are in Redis (7 days)
            // We rely on polling to get new messages
            
            NetworkLogger.shared.log("ℹ️ Message history loaded from local DB only (backend stores metadata only)")
            
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Error loading messages: \(error)")
        }

        isLoading = false
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        NetworkLogger.shared.log("📨 ChatViewModel.sendMessage() started", group: "Debug")
        NetworkLogger.shared.log("  Text: \(text.prefix(50))", group: "Debug")
        
        guard !text.isEmpty else {
            NetworkLogger.shared.log("❌ Text is empty", group: "Debug")
            return
        }
        
        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            NetworkLogger.shared.log("❌ No token found", group: "Debug")
            return
        }
        
        NetworkLogger.shared.log("✅ Token found: \(token.prefix(20))...", group: "Debug")

        isSending = true
        errorMessage = nil

        do {
            // Encrypt message with Signal Protocol
            NetworkLogger.shared.log("🔐 Encrypting message with Signal Protocol...", group: "Debug")
            
            let encryptedPayload = try await EncryptionManager.shared.encrypt(
                message: text,
                for: otherUserId,
                token: token
            )
            
            NetworkLogger.shared.log("✅ Message encrypted: \(encryptedPayload.prefix(50))...", group: "Debug")
            
            // 2. Send encrypted payload to backend
            NetworkLogger.shared.log("📤 Sending payload to backend", group: "Debug")
            
            let response = try await APIClient.shared.sendMessage(
                token: token,
                toUserId: otherUserId,
                encryptedPayload: encryptedPayload
            )

            NetworkLogger.shared.log("✅ Message sent: \(response.messageId)")

            // 3. Save to local SwiftData (decrypted locally)
            guard let currentUserId = currentUserId,
                  let chatId = chatId,
                  let modelContext = modelContext else {
                NetworkLogger.shared.log("⚠️ Missing context for saving message", group: "Debug")
                NetworkLogger.shared.log("  currentUserId: \(currentUserId?.uuidString ?? "nil")", group: "Debug")
                NetworkLogger.shared.log("  chatId: \(chatId?.uuidString ?? "nil")", group: "Debug")
                NetworkLogger.shared.log("  modelContext: \(modelContext != nil ? "exists" : "nil")", group: "Debug")
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
            
            NetworkLogger.shared.log("💾 Message saved to local DB", group: "Debug")
            NetworkLogger.shared.log("   Message ID: \(messageUUID)", group: "Debug")
            NetworkLogger.shared.log("   Chat ID: \(chatId)", group: "Debug")
            NetworkLogger.shared.log("   Sender: \(currentUserId)", group: "Debug")
            NetworkLogger.shared.log("   Recipient: \(recipientUUID)", group: "Debug")
            
            // Update Chat's lastMessageAt (or create if doesn't exist)
            let chatDescriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )
            
            if let chat = try? modelContext.fetch(chatDescriptor).first {
                // Update existing chat
                chat.lastMessageText = text
                chat.lastMessageAt = Date()
                try? modelContext.save()
                NetworkLogger.shared.log("✅ Updated existing chat", group: "Debug")
            } else {
                // Create new chat
                NetworkLogger.shared.log("🆕 Chat doesn't exist, creating new one...", group: "Debug")
                
                let newChat = Chat(
                    id: chatId,
                    type: .oneToOne,
                    otherUserId: recipientUUID,
                    otherUserName: otherUserName,
                    otherUserDisplayName: otherUserName
                )
                newChat.lastMessageText = text
                newChat.lastMessageAt = Date()
                
                modelContext.insert(newChat)
                try? modelContext.save()
                
                NetworkLogger.shared.log("✅ Created new chat with ID: \(chatId)", group: "Debug")
            }
            
            // Add to UI
            messages.append(newMessage)
            
            NetworkLogger.shared.log("✅ Message added to UI array (count: \(messages.count))", group: "Debug")

            // Success haptic
            HapticManager.shared.success()

        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Error sending message: \(error)")
            HapticManager.shared.error()
        }

        isSending = false
    }
    
    // MARK: - Send Image
    
    func sendImage(_ image: UIImage) async {
        guard let token = getToken() else {
            errorMessage = "Not authenticated"
            return
        }

        isSending = true
        errorMessage = nil

        do {
            // 1. Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                throw MediaError.compressionFailed
            }
            
            let sizeKB = imageData.count / 1024
            NetworkLogger.shared.log("📸 Image compressed: \(sizeKB)KB")
            
            // Check file size limit (10MB)
            let maxSizeBytes = 10 * 1024 * 1024
            if imageData.count > maxSizeBytes {
                throw MediaError.fileSizeExceeded
            }
            
            // 2. Encrypt image data
            let encryptedImageData = try await EncryptionManager.shared.encryptData(
                data: imageData,
                for: otherUserId,
                token: token
            )
            
            NetworkLogger.shared.log("🔐 Image encrypted: \(encryptedImageData.count) bytes")
            
            // 3. Upload to backend
            let messageId = UUID()
            
            // Try to upload to backend media service
            let mediaURL: String
            do {
                let uploadResponse = try await APIClient.shared.uploadMedia(
                    token: token,
                    mediaData: encryptedImageData,
                    mediaType: "image/jpeg",
                    recipientId: otherUserId
                )
                mediaURL = uploadResponse.mediaURL
                NetworkLogger.shared.log("☁️ Image uploaded to server: \(mediaURL)")
            } catch {
                // Fallback: Save locally if upload fails
                NetworkLogger.shared.log("⚠️ Server upload failed, saving locally: \(error)")
                
                guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw MediaError.saveFailed
                }
                
                let localImagePath = documentsPath.appendingPathComponent("\(messageId.uuidString).jpg")
                try imageData.write(to: localImagePath)
                mediaURL = localImagePath.absoluteString
                
                NetworkLogger.shared.log("💾 Image saved locally: \(localImagePath.lastPathComponent)")
            }
            
            // 4. Save message to SwiftData
            guard let currentUserId = currentUserId,
                  let chatId = chatId,
                  let modelContext = modelContext,
                  let recipientUUID = UUID(uuidString: otherUserId) else {
                NetworkLogger.shared.log("⚠️ Missing context for saving image message")
                isSending = false
                return
            }
            
            let newMessage = Message(
                id: messageId,
                content: "[Photo]", // Placeholder text
                senderId: currentUserId,
                recipientId: recipientUUID,
                chatId: chatId,
                contentType: .image,
                status: .sent,
                isFromCurrentUser: true,
                timestamp: Date()
            )
            
            // Set media URL
            newMessage.mediaURLString = mediaURL
            
            // Save to SwiftData
            modelContext.insert(newMessage)
            try modelContext.save()
            
            // Add to UI
            messages.append(newMessage)
            
            NetworkLogger.shared.log("✅ Image message saved")
            HapticManager.shared.success()

        } catch {
            errorMessage = "Failed to send image: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Error sending image: \(error)")
            HapticManager.shared.error()
        }

        isSending = false
    }

    // MARK: - Helpers

    private func getToken() -> String? {
        let keychainHelper = KeychainHelper()
        guard let tokenData = try? keychainHelper.load(forKey: KeychainHelper.Keys.authToken),
              let token = String(data: tokenData, encoding: .utf8) else {
            NetworkLogger.shared.log("❌ Failed to load token from Keychain", group: "Debug")
            return nil
        }
        return token
    }
}
