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
    private let pollingInterval: TimeInterval = 2.0 // 2 seconds for faster delivery (testing)
    
    // SwiftData context for saving messages
    private var modelContext: ModelContext?
    private var currentUserId: UUID?
    
    // Track processed messages to avoid duplicates
    private var processedMessageIds = Set<String>()
    
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
            // 1. First, load from local SwiftData (instant UI)
            await loadLocalChats()
            
            NetworkLogger.shared.log("✅ Loaded \(chats.count) chats from local DB")
            
            // 2. Try to fetch from backend to sync (with timeout protection)
            do {
                let response = try await withTimeout(seconds: 5) {
                    try await APIClient.shared.getChats(token: token)
                }
                
                // 3. Merge backend chats with local chats
                var allChats = response.chats
                
                // Add local-only chats (chats created but not yet synced to backend)
                if let modelContext = modelContext {
                    let localChats = try? modelContext.fetch(FetchDescriptor<Chat>())
                    
                    for localChat in localChats ?? [] {
                        // Check if this chat is already in backend response
                        let existsInBackend = allChats.contains { $0.userId == localChat.otherUserId?.uuidString }
                        
                        if !existsInBackend {
                            // Add local-only chat to the list
                            let chatInfo = ChatInfo(
                                userId: localChat.otherUserId?.uuidString ?? "",
                                username: localChat.otherUserName ?? "Unknown",
                                displayName: localChat.otherUserDisplayName,
                                isOnline: false, // We don't know, assume offline
                                lastSeen: nil,
                                lastMessageAt: localChat.lastMessageAt?.ISO8601Format(),
                                lastMessageStatus: nil
                            )
                            allChats.append(chatInfo)
                            NetworkLogger.shared.log("✅ Added local-only chat: \(localChat.otherUserName ?? "Unknown")")
                        }
                    }
                }
                
                chats = allChats.sorted { ($0.lastMessageAt ?? "") > ($1.lastMessageAt ?? "") }
                NetworkLogger.shared.log("✅ Synced with backend: \(chats.count) total chats")
            } catch {
                // If backend fetch fails, continue with local chats
                NetworkLogger.shared.log("⚠️ Backend sync failed, using local chats only: \(error)")
                // Don't set errorMessage here, we still have local data
            }
            
        } catch {
            // Critical error (e.g., local DB failure)
            errorMessage = "Failed to load chats: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Critical error loading chats: \(error)")
        }

        isLoading = false
    }
    
    // Helper function for timeout protection
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func loadLocalChats() async {
        guard let modelContext = modelContext else { return }
        
        do {
            let localChats = try modelContext.fetch(FetchDescriptor<Chat>())
            
            chats = localChats.map { chat in
                ChatInfo(
                    userId: chat.otherUserId?.uuidString ?? "",
                    username: chat.otherUserName ?? "Unknown",
                    displayName: chat.otherUserDisplayName,
                    isOnline: false,
                    lastSeen: nil,
                    lastMessageAt: chat.lastMessageAt?.ISO8601Format(),
                    lastMessageStatus: nil
                )
            }.sorted { ($0.lastMessageAt ?? "") > ($1.lastMessageAt ?? "") }
            
            NetworkLogger.shared.log("✅ Loaded \(chats.count) chats from local DB")
        } catch {
            NetworkLogger.shared.log("❌ Error loading local chats: \(error)")
        }
    }

    // MARK: - Polling

    func startPolling() {
        stopPolling() // Stop any existing timer

        guard let token = getToken() else { return }

        NetworkLogger.shared.log("🔄 Starting message polling (every \(pollingInterval)s)", group: "Polling")

        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                NetworkLogger.shared.log("⏰ [POLL] Timer fired - polling now...", group: "Polling")
                await self?.pollMessages()
            }
        }

        // Poll immediately
        NetworkLogger.shared.log("🚀 [POLL] Initial poll starting...", group: "Polling")
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
        guard let token = getToken() else {
            NetworkLogger.shared.log("❌ [POLL] No token available", group: "Polling")
            return
        }

        NetworkLogger.shared.log("📡 [POLL] Polling backend for new messages...", group: "Polling")
        
        do {
            let response = try await APIClient.shared.pollMessages(token: token)

            NetworkLogger.shared.log("📥 [POLL] Backend response: \(response.messages.count) messages", group: "Polling")
            
            if !response.messages.isEmpty {
                NetworkLogger.shared.log("📬 [POLL] Received \(response.messages.count) new messages from backend", group: "Polling")

                // Filter out already processed messages
                let newMessages = response.messages.filter { !processedMessageIds.contains($0.id) }
                
                if newMessages.isEmpty {
                    NetworkLogger.shared.log("⏭️ [POLL] All \(response.messages.count) messages already processed (duplicates filtered)", group: "Polling")
                    return
                }
                
                NetworkLogger.shared.log("✅ [POLL] Processing \(newMessages.count) new unique messages", group: "Polling")

                // Process each new message
                for (index, message) in newMessages.enumerated() {
                    NetworkLogger.shared.log("📨 [POLL] Processing message \(index + 1)/\(newMessages.count): \(message.id)", group: "Polling")
                    await handleNewMessage(message)
                    processedMessageIds.insert(message.id)
                }

                // Reload chats to update UI (only if we processed new messages)
                NetworkLogger.shared.log("🔄 [POLL] Reloading chats after processing messages", group: "Polling")
                await loadChats()
                NetworkLogger.shared.log("✅ [POLL] Chats reloaded successfully", group: "Polling")
            } else {
                // Silent when no messages (don't spam console)
                NetworkLogger.shared.log("💤 [POLL] No new messages", group: "Polling")
            }
        } catch {
            NetworkLogger.shared.log("⚠️ [POLL] Polling error: \(error.localizedDescription)", group: "Polling")
        }
    }

    private func handleNewMessage(_ message: OfflineMessage) async {
        guard let token = getToken() else { return }

        NetworkLogger.shared.log("📨 [MSG] New message from \(message.from)", group: "Messages")

        do {
            // Decrypt message payload using Signal Protocol
            NetworkLogger.shared.log("🔐 [MSG] Decrypting message payload...", group: "Messages")
            
            let decryptedText = try await EncryptionManager.shared.decrypt(
                payload: message.payload,
                from: message.from,
                token: token
            )
            
            NetworkLogger.shared.log("✅ [MSG] Message decrypted successfully", group: "Messages")
            NetworkLogger.shared.log("📝 [MSG] Content: \(decryptedText.prefix(50))...", group: "Messages")

            // 2. Save to SwiftData
            guard let modelContext = modelContext,
                  let currentUserId = currentUserId else {
                NetworkLogger.shared.log("⚠️ [MSG] ModelContext not configured", group: "Messages")
                // Still send ACK even if save fails
                try? await APIClient.shared.sendAck(token: token, messageId: message.id, status: "delivered")
                return
            }
            
            // Convert String IDs to UUIDs
            guard let senderUUID = UUID(uuidString: message.from),
                  let messageUUID = UUID(uuidString: message.id) else {
                NetworkLogger.shared.log("⚠️ [MSG] Invalid UUID format", group: "Messages")
                return
            }
            
            // Generate deterministic chatId
            let chatId = generateChatId(userId1: currentUserId, userId2: senderUUID)
            
            // Check if message already exists (prevent duplicates)
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageUUID }
            )
            
            let existingMessages = try? modelContext.fetch(descriptor)
            if let existing = existingMessages, !existing.isEmpty {
                NetworkLogger.shared.log("⚠️ [MSG] Message already exists in DB, skipping", group: "Messages")
                // Still send ACK
                try await APIClient.shared.sendAck(token: token, messageId: message.id, status: "delivered")
                return
            }
            
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
            
            NetworkLogger.shared.log("💾 [MSG] Saved to SwiftData", group: "Messages")
            
            // Create or update Chat
            let chatDescriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.id == chatId }
            )
            
            if let chat = try? modelContext.fetch(chatDescriptor).first {
                // Update existing chat
                chat.lastMessageText = decryptedText
                chat.lastMessageAt = Date()
                chat.unreadCount += 1
                try? modelContext.save()
                NetworkLogger.shared.log("✅ [MSG] Updated existing chat", group: "Messages")
            } else {
                // Create new chat
                NetworkLogger.shared.log("🆕 [MSG] Creating new chat for sender \(message.from.prefix(8))...", group: "Messages")
                
                // Try to get sender's username from backend
                var senderUsername = message.from.prefix(8).description
                do {
                    let userResponse = try await APIClient.shared.getUserPublicKeys(token: token, userId: message.from)
                    senderUsername = userResponse.keys.username
                    NetworkLogger.shared.log("✅ [MSG] Fetched sender username: \(senderUsername)", group: "Messages")
                } catch {
                    NetworkLogger.shared.log("⚠️ [MSG] Could not fetch sender username: \(error)", group: "Messages")
                }
                
                let newChat = Chat(
                    id: chatId,
                    type: .oneToOne,
                    otherUserId: senderUUID,
                    otherUserName: senderUsername,
                    otherUserDisplayName: senderUsername,
                    unreadCount: 1
                )
                newChat.lastMessageText = decryptedText
                newChat.lastMessageAt = Date()
                
                modelContext.insert(newChat)
                try modelContext.save()
                
                NetworkLogger.shared.log("✅ [MSG] Created new chat with \(senderUsername)", group: "Messages")
            }
            
            // Post notification for active chat view to refresh
            NotificationCenter.default.post(
                name: NSNotification.Name("NewMessageReceived"),
                object: nil,
                userInfo: ["chatId": chatId.uuidString, "message": newMessage]
            )

            // 3. Send ACK
            try await APIClient.shared.sendAck(token: token, messageId: message.id, status: "delivered")
            NetworkLogger.shared.log("✅ [MSG] ACK sent for \(message.id)", group: "Messages")

            // Success feedback - stronger haptic for new message
            HapticManager.shared.success()

        } catch {
            NetworkLogger.shared.log("❌ [MSG] Error: \(error)", group: "Messages")
            HapticManager.shared.error()
        }
    }

    // MARK: - Helpers
    
    // Generate deterministic chat ID from two user IDs (same as ChatViewModel)
    private func generateChatId(userId1: UUID, userId2: UUID) -> UUID {
        // Sort UUIDs to ensure same chatId regardless of order
        let sorted = [userId1, userId2].sorted { $0.uuidString < $1.uuidString }
        let combined = sorted[0].uuidString + sorted[1].uuidString
        
        // Use XOR-based deterministic UUID generation
        guard let data = combined.data(using: .utf8) else {
            NetworkLogger.shared.log("❌ Failed to create chat ID from user IDs", group: "Debug")
            return UUID()
        }
        
        // Create a deterministic UUID using the first 16 bytes of hash
        let hashData = data.withUnsafeBytes { buffer in
            var hash = [UInt8](repeating: 0, count: 16)
            for (index, byte) in buffer.enumerated() {
                hash[index % 16] ^= byte
            }
            return Data(hash)
        }
        
        // Convert to UUID string format
        let bytes = [UInt8](hashData.prefix(16))
        let uuidString = String(format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                               bytes[0], bytes[1], bytes[2], bytes[3],
                               bytes[4], bytes[5],
                               bytes[6], bytes[7],
                               bytes[8], bytes[9],
                               bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        
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
