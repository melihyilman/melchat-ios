import Foundation
import Combine

/// WebSocket manager for real-time messaging
class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    @Published var isConnected = false
    @Published var receivedMessages: [ReceivedMessage] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var userId: String?

    private init() {}

    // MARK: - Connect

    func connect(userId: String) {
        self.userId = userId
        
        // Simulator için localhost, gerçek cihaz için Mac IP
        #if targetEnvironment(simulator)
        let wsURL = "ws://localhost:3000/ws/messaging"
        #else
        let wsURL = "ws://192.168.1.116:3000/ws/messaging" // TODO: Mac'in gerçek IP'sini buraya yaz
        #endif
        
        guard let url = URL(string: wsURL) else {
            NetworkLogger.shared.log("❌ Invalid WebSocket URL: \(wsURL)")
            return
        }

        NetworkLogger.shared.log("🔌 Connecting to WebSocket: \(wsURL)")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Authenticate
        sendAuth(userId: userId)

        // Start receiving messages
        receiveMessage()

        // Start heartbeat
        startHeartbeat()

        isConnected = true
        reconnectAttempts = 0
        
        NetworkLogger.shared.log("✅ WebSocket connected for user: \(userId)")
    }

    // MARK: - Disconnect

    func disconnect() {
        NetworkLogger.shared.log("🔌 Disconnecting WebSocket...")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        userId = nil
        NetworkLogger.shared.log("✅ WebSocket disconnected")
    }

    // MARK: - Send Auth

    private func sendAuth(userId: String) {
        let message = WebSocketMessage(type: "auth", userId: userId)
        send(message)
    }

    // MARK: - Send Message

    func sendMessage(toUserId: String, encryptedMessage: String) {
        guard isConnected else {
            print("❌ Not connected")
            return
        }

        let message = SendMessagePayload(
            type: "send_message",
            toUserId: toUserId,
            encryptedPayload: encryptedMessage  // String
        )

        send(message)
    }

    // MARK: - Send ACK

    func sendAck(messageId: String, status: String) {
        let message = AckPayload(
            type: "ack",
            messageId: messageId,
            status: status
        )

        send(message)
    }

    // MARK: - Generic Send

    private func send<T: Encodable>(_ message: T) {
        guard let data = try? JSONEncoder().encode(message),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("❌ Failed to encode message")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("❌ WebSocket send error: \(error)")
                self.handleDisconnect()
            }
        }
    }

    // MARK: - Receive Message

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }

                // Continue receiving
                self?.receiveMessage()

            case .failure(let error):
                print("❌ WebSocket receive error: \(error)")
                self?.handleDisconnect()
            }
        }
    }

    // MARK: - Handle Message

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        DispatchQueue.main.async {
            switch type {
            case "auth_success":
                print("✅ WebSocket authenticated")

            case "new_message":
                if let messageData = json["message"] as? [String: Any],
                   let received = try? JSONDecoder().decode(ReceivedMessage.self, from: JSONSerialization.data(withJSONObject: messageData)) {
                    self.receivedMessages.append(received)
                    print("✅ New message received")
                }

            case "offline_messages":
                if let messages = json["messages"] as? [[String: Any]] {
                    print("✅ Received \(messages.count) offline messages")
                    // TODO: Process offline messages
                }

            case "message_sent":
                print("✅ Message sent")

            case "ack":
                print("✅ ACK received")

            case "pong":
                // Heartbeat response
                break

            case "error":
                if let message = json["message"] as? String {
                    print("❌ Server error: \(message)")
                }

            default:
                print("⚠️ Unknown message type: \(type)")
            }
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard self?.isConnected == true else { return }
            let message = WebSocketMessage(type: "ping")
            self?.send(message)
        }
    }

    // MARK: - Reconnect

    private func handleDisconnect() {
        isConnected = false

        guard reconnectAttempts < maxReconnectAttempts,
              let userId = userId else {
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("🔄 Reconnecting... (attempt \(self.reconnectAttempts))")
            self.connect(userId: userId)
        }
    }
}

// MARK: - Models

struct WebSocketMessage: Encodable {
    let type: String
    let userId: String?

    init(type: String, userId: String? = nil) {
        self.type = type
        self.userId = userId
    }
}

struct SendMessagePayload: Encodable {
    let type: String
    let toUserId: String
    let encryptedPayload: String  // ✅ String (not object)
}

// DEPRECATED - Old function using object
// func sendMessage(toUserId: String, encryptedPayload: EncryptedPayload)

struct AckPayload: Encodable {
    let type: String
    let messageId: String
    let status: String
}

struct ReceivedMessage: Codable, Identifiable {
    let id: String
    let from: String
    let to: String
    let encryptedPayload: String  // ✅ Backend sends "encryptedPayload"
    let timestamp: String
    
    // Map to encryptedMessage for internal use
    var encryptedMessage: String {
        return encryptedPayload
    }
}
