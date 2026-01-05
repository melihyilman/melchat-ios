# 🏛️ MELCHAT ARCHITECTURE

> **Purpose:** High-level overview of app architecture, design patterns, and data flow.

---

## 📐 Architecture Pattern

**MVVM + Repository Pattern**

```
┌─────────────┐
│    Views    │ ← SwiftUI Views
└──────┬──────┘
       │ @Published
       ▼
┌─────────────┐
│ ViewModels  │ ← Business Logic
└──────┬──────┘
       │ async/await
       ▼
┌─────────────┐
│ Services    │ ← API, Storage, Encryption
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Backend   │ ← REST API / WebSocket
└─────────────┘
```

---

## 🎯 Core Principles

### 1. Single Responsibility
Each service has ONE clear purpose:
- `APIClient` → REST API only
- `WebSocketManager` → WebSocket only
- `SimpleEncryption` → Encryption only

### 2. Dependency Injection
ViewModels receive dependencies (context, userId):
```swift
chatViewModel.configure(
    modelContext: context,
    currentUserId: userId,
    chatId: chatId
)
```

### 3. Actor Isolation
- `@MainActor` for UI-related classes
- Proper async/await usage
- No data races

### 4. Single Source of Truth
- One encryption service
- One models file
- One keychain helper
- Registry tracks all services

---

## 📦 Layers

### Layer 1: UI (Views)
**Technology:** SwiftUI  
**Responsibility:** Display data, handle user input

```swift
struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        // UI only, no business logic
    }
}
```

**Rules:**
- No business logic
- No direct API calls
- No encryption logic
- Delegate everything to ViewModels

---

### Layer 2: ViewModels
**Technology:** ObservableObject + @MainActor  
**Responsibility:** Business logic, state management

```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    
    func sendMessage(_ text: String) async {
        // 1. Encrypt with SimpleEncryption
        // 2. Send via APIClient
        // 3. Save to SwiftData
        // 4. Update UI via @Published
    }
}
```

**Rules:**
- Coordinate between services
- Manage UI state
- Handle errors
- No direct UI code

---

### Layer 3: Services (Core)
**Technology:** Singleton pattern, async/await  
**Responsibility:** Specific functionality

#### Networking Services
```swift
APIClient.shared           // REST API
WebSocketManager.shared    // Real-time
NetworkLogger.shared       // Debugging
MessageReceiver.shared     // Message handling
```

#### Security Services
```swift
SimpleEncryption.shared    // E2E encryption
KeychainHelper()           // Secure storage
TokenManager.shared        // JWT tokens
```

#### Storage
```swift
Models.swift               // SwiftData models
```

**Rules:**
- One responsibility per service
- No UI logic
- Testable
- Well-documented

---

### Layer 4: Storage (SwiftData)
**Technology:** SwiftData  
**Responsibility:** Local data persistence

```swift
@Model
class Message {
    var id: UUID
    var content: String
    var senderId: UUID
    var timestamp: Date
    // ...
}
```

**Rules:**
- All models in ONE file
- Use @Model macro
- Proper relationships
- Unique IDs

---

## 🔄 Data Flow

### Sending a Message

```
┌──────────────────────────────────────────────────────────┐
│ 1. User Types Message                                   │
│    ChatDetailView → TextField                            │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 2. ViewModel Handles                                     │
│    ChatViewModel.sendMessage(text)                       │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 3. Get Recipient's Public Key                            │
│    APIClient.shared.getPublicKey(userId)                 │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 4. Encrypt Message                                       │
│    SimpleEncryption.shared.encrypt(message, publicKey)   │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 5. Send to Backend                                       │
│    APIClient.shared.sendEncryptedMessage(ciphertext)     │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 6. Save to Local DB                                      │
│    modelContext.insert(message)                          │
│    modelContext.save()                                   │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 7. Update UI                                             │
│    @Published messages updated → View refreshes          │
└──────────────────────────────────────────────────────────┘
```

---

### Receiving a Message

```
┌──────────────────────────────────────────────────────────┐
│ 1. Backend Sends Message                                 │
│    WebSocket "new_message" event                         │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 2. WebSocket Receives                                    │
│    WebSocketManager.$receivedMessages updated            │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 3. Message Receiver Handles                              │
│    MessageReceiver.handleReceivedMessage()               │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 4. Get Sender's Public Key                               │
│    APIClient.shared.getPublicKey(senderId)               │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 5. Decrypt Message                                       │
│    SimpleEncryption.shared.decrypt(ciphertext, publicKey)│
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 6. Save to Local DB                                      │
│    modelContext.insert(message)                          │
│    modelContext.save()                                   │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 7. Notify UI                                             │
│    NotificationCenter.post("NewMessageReceived")         │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 8. ViewModel Reloads                                     │
│    ChatViewModel.reloadMessagesFromDB()                  │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│ 9. UI Updates                                            │
│    @Published messages → View refreshes                  │
└──────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Architecture

### End-to-End Encryption Flow

```
┌──────────────────────────────────────────────────────────┐
│               SimpleEncryption (Curve25519)              │
│                                                           │
│  User A                        User B                    │
│  ┌──────┐                      ┌──────┐                 │
│  │ Priv │                      │ Priv │                 │
│  │  Key │                      │  Key │                 │
│  └──┬───┘                      └───┬──┘                 │
│     │                              │                     │
│     ▼                              ▼                     │
│  ┌──────┐                      ┌──────┐                 │
│  │ Pub  │──────────────────────▶│ Pub  │                 │
│  │  Key │◀──────────────────────│  Key │                 │
│  └──────┘     (via backend)    └──────┘                 │
│                                                           │
│  ECDH: Shared Secret = Priv_A × Pub_B = Priv_B × Pub_A  │
│                                                           │
│  Shared Secret → HKDF → AES-GCM-256 Key                 │
│                                                           │
│  Encrypt: plaintext → AES-GCM → ciphertext              │
│  Decrypt: ciphertext → AES-GCM → plaintext              │
└──────────────────────────────────────────────────────────┘
```

**Key Points:**
- Keys never leave device (except public key)
- Backend cannot decrypt (no private keys)
- Perfect forward secrecy (each session unique)

---

## 📱 App State Management

### AppState (Global State)

```swift
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserId: UUID?
    
    func login(userId: UUID)
    func logout()
}
```

**Flows:**
- Login → Set `isAuthenticated = true`
- Logout → Clear tokens, set `isAuthenticated = false`
- ContentView switches between LoginView and MainTabView

---

## 🔄 Concurrency Model

### Swift 6 Strict Concurrency

```swift
// ✅ Main Actor for UI
@MainActor
class ChatViewModel: ObservableObject { }

// ✅ Async/await for networking
func sendMessage() async {
    let response = try await APIClient.shared.send(...)
}

// ✅ Task for background work
Task {
    await heavyWork()
}

// ✅ Actor isolation for thread safety
// (All ViewModels are @MainActor)
```

**Rules:**
- All ViewModels → `@MainActor`
- All network calls → `async/await`
- No callback hell → Use structured concurrency
- Timer closures → Wrap in `Task { @MainActor in }`

---

## 🧪 Testing Strategy

### Unit Tests
```swift
// Test ViewModels
class ChatViewModelTests: XCTestCase {
    func testSendMessage() async {
        // Mock dependencies
        // Test business logic
    }
}

// Test Services
class SimpleEncryptionTests: XCTestCase {
    func testEncryptDecrypt() {
        // Test encryption/decryption
    }
}
```

### Integration Tests
- Test full message flow (encrypt → send → receive → decrypt)
- Test authentication flow
- Test WebSocket connection

---

## 📊 Performance Considerations

### SwiftData
- In-memory mode during development
- Persistent mode in production
- Indexed queries on frequently searched fields

### Encryption
- Async operations to avoid blocking UI
- Cached keys in memory (not re-reading from Keychain each time)

### Networking
- Auto-token refresh (no manual refresh needed)
- Connection pooling via URLSession
- WebSocket for real-time (no polling)

---

## 🎨 Design Patterns Used

1. **Singleton** - Services (APIClient, WebSocketManager, etc.)
2. **Observer** - SwiftUI @Published, Combine
3. **Repository** - ViewModels coordinate between services
4. **Dependency Injection** - ViewModels receive context/userId
5. **Factory** - Message creation

---

## 📝 Best Practices

### ✅ DO:
- Use `@MainActor` for ViewModels
- Use `async/await` for async work
- Check `SERVICES_REGISTRY.md` before creating services
- One model file (`Models.swift`)
- Proper error handling
- NetworkLogger for debugging

### ❌ DON'T:
- Create duplicate services
- Use callbacks (use async/await)
- Put business logic in Views
- Create multiple model files
- Use deprecated encryption

---

## 🚀 Deployment Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      iOS App (Client)                     │
│                                                           │
│  SwiftUI Views ← ViewModels ← Services                   │
│                                                           │
│  SimpleEncryption (E2E) ──────────────────────┐          │
│  SwiftData (Local DB) ─────────────────────┐  │          │
└──────────────┬─────────────────────────────┼──┼──────────┘
               │                             │  │
               │ REST API / WebSocket        │  │
               ▼                             │  │
┌──────────────────────────────────────────┐ │  │
│         Backend Server (Node.js)         │ │  │
│                                          │ │  │
│  - User management                       │ │  │
│  - Message routing (encrypted)           │◀┘  │
│  - Key distribution (public keys)        │    │
│  - WebSocket server                      │    │
│  - Cannot decrypt messages! 🔒           │    │
└──────────────┬───────────────────────────┘    │
               │                                 │
               ▼                                 │
┌──────────────────────────────────────────┐    │
│        Database (PostgreSQL/MongoDB)     │    │
│                                          │    │
│  - Users                                 │    │
│  - Public keys                           │    │
│  - Encrypted messages (ciphertext only)  │◀───┘
└──────────────────────────────────────────┘
```

---

## 📚 Related Documentation

- `SERVICES_REGISTRY.md` - All services
- `PROJECT_STRUCTURE.md` - Folder organization
- `CODING_GUIDELINES.md` - Code style

---

**Status: ✅ DOCUMENTED**

Last Updated: 2026-01-05
