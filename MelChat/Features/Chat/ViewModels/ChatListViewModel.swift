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

            // 2. TODO: Save to SwiftData

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

    private func getToken() -> String? {
        let keychainHelper = KeychainHelper()
        guard let tokenData = try? keychainHelper.load(forKey: KeychainHelper.Keys.authToken),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}
