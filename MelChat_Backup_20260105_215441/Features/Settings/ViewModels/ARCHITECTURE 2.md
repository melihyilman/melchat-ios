# 🏗️ MELCHAT ARCHITECTURE

> Professional iOS messaging app with E2E encryption

Last Updated: 2026-01-05

---

## 📐 Architecture Overview

MelChat follows a **feature-based MVVM architecture** with clear separation of concerns.

```
┌─────────────────────────────────────────────────────────────┐
│                        MelChat App                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐      ┌──────────────┐     ┌─────────────┐ │
│  │   Views     │ ───▶ │  ViewModels  │ ──▶ │  Services   │ │
│  │  (SwiftUI)  │ ◀─── │ (Observable) │ ◀── │ (Singletons)│ │
│  └─────────────┘      └──────────────┘     └─────────────┘ │
│         │                     │                     │        │
│         ▼                     ▼                     ▼        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              SwiftData (Local Storage)               │   │
│  └─────────────────────────────────────────────────────┘   │
│         │                     │                     │        │
│         ▼                     ▼                     ▼        │
│  ┌─────────────┐      ┌──────────────┐     ┌─────────────┐ │
│  │  APIClient  │      │  WebSocket   │     │ Encryption  │ │
│  │   (REST)    │      │  (Real-time) │     │  (E2E)      │ │
│  └─────────────┘      └──────────────┘     └─────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
MelChat/
├── App/
│   ├── MelChatApp.swift              # @main entry point
│   └── AppState.swift                # Global app state
│
├── Core/                             # Reusable core functionality
│   ├── Networking/
│   │   ├── APIClient.swift           # REST API
│   │   ├── WebSocketManager.swift    # Real-time messaging
│   │   ├── TokenManager.swift        # JWT management
│   │   └── NetworkLogger.swift       # Debug logging
│   │
│   ├── Security/
│   │   ├── SimpleEncryption.swift    # E2E encryption
│   │   ├── KeychainHelper.swift      # Secure storage
│   │   └── (future: Biometrics)
│   │
│   ├── Storage/
│   │   └── Models/
│   │       └── Models.swift          # SwiftData models
│   │
│   └── Utilities/
│       ├── HapticManager.swift       # Haptic feedback
│       ├── MessageReceiver.swift     # Message handling
│       └── VoiceRecorder.swift       # Voice messages
│
├── Features/                         # Feature modules
│   ├── Authentication/
│   │   ├── ViewModels/
│   │   │   └── AuthViewModel.swift
│   │   └── Views/
│   │       └── AuthViews.swift
│   │
│   ├── Chat/
│   │   ├── ViewModels/
│   │   │   ├── ChatViewModel.swift
│   │   │   └── ChatListViewModel.swift
│   │   └── Views/
│   │       └── ChatViews.swift
│   │
│   └── Settings/
│       ├── ViewModels/
│       │   └── SettingsViewModel.swift
│       └── Views/
│           └── SettingsView.swift
│
├── UI/                               # Reusable UI components
│   ├── AnimatedCharacters.swift
│   ├── PikachuAnimationView.swift
│   └── ContentView.swift
│
└── Resources/                        # Documentation
    ├── SERVICES_REGISTRY.md          # Service documentation
    ├── ARCHITECTURE.md               # This file
    └── PROJECT_STRUCTURE.md          # Setup guide
```

---

## 🎯 Design Patterns

### 1. **MVVM (Model-View-ViewModel)**

```swift
// Model (SwiftData)
@Model
class Message {
    var content: String
    var senderId: UUID
    // ...
}

// ViewModel (@MainActor ObservableObject)
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    
    func sendMessage(_ text: String) async {
        // Business logic
    }
}

// View (SwiftUI)
struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    
    var body: some View {
        // UI
    }
}
```

### 2. **Singleton Pattern (Services)**

```swift
@MainActor
class SimpleEncryption {
    static let shared = SimpleEncryption()
    private init() {}
    
    // Service methods
}
```

### 3. **Repository Pattern (Networking)**

```swift
class APIClient {
    static let shared = APIClient()
    
    func sendMessage(...) async throws -> Response {
        // Network logic
    }
}
```

---

## 🔐 Security Architecture

### End-to-End Encryption Flow

```
┌──────────────────────────────────────────────────────────┐
│                    Message Sending                        │
└──────────────────────────────────────────────────────────┘

1. User types message
   ↓
2. ChatViewModel.sendMessage()
   ↓
3. Get recipient's public key (APIClient)
   ↓
4. Encrypt with SimpleEncryption (Curve25519 + AES-GCM)
   ↓
5. Send ciphertext to backend (APIClient)
   ↓
6. Save to local SwiftData (encrypted)
   ↓
7. UI updates (message appears)


┌──────────────────────────────────────────────────────────┐
│                   Message Receiving                       │
└──────────────────────────────────────────────────────────┘

1. WebSocket receives message
   ↓
2. MessageReceiver.handleReceivedMessage()
   ↓
3. Get sender's public key (APIClient)
   ↓
4. Decrypt with SimpleEncryption
   ↓
5. Save to SwiftData (decrypted for quick access)
   ↓
6. Post notification
   ↓
7. ChatViewModel updates UI
```

### Encryption Details

- **Key Exchange:** ECDH (Curve25519)
- **Symmetric Encryption:** AES-GCM-256
- **Key Storage:** Keychain with iCloud sync
- **Transport Security:** HTTPS + TLS 1.3

---

## 💾 Data Flow

### SwiftData (Local Storage)

```swift
// Models
@Model class User
@Model class Message
@Model class Chat
@Model class Group

// Usage in ViewModel
@MainActor
class ChatViewModel: ObservableObject {
    private var modelContext: ModelContext?
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func loadMessages() async {
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.chatId == chatId }
        )
        messages = try modelContext.fetch(descriptor)
    }
}
```

### Data Persistence Layers

1. **SwiftData** - Local database (messages, chats, users)
2. **Keychain** - Sensitive data (tokens, keys)
3. **UserDefaults** - App preferences (settings)

---

## 🌐 Networking Architecture

### Dual Communication

```
┌─────────────┐         ┌──────────────┐
│  APIClient  │         │  WebSocket   │
│   (REST)    │         │  (Real-time) │
└─────────────┘         └──────────────┘
      │                        │
      │ HTTP/2 + HTTPS         │ WSS (WebSocket Secure)
      ▼                        ▼
┌──────────────────────────────────────┐
│          Backend Server               │
│  (Node.js + Express + PostgreSQL)    │
└──────────────────────────────────────┘
```

### When to Use Each

**APIClient (REST):**
- Authentication (login, signup)
- User profile updates
- Fetching chat history
- Uploading encryption keys
- Polling for offline messages

**WebSocketManager (Real-time):**
- Live message delivery
- Typing indicators (future)
- Online status updates (future)
- Read receipts (future)

---

## 🔄 State Management

### Global State (AppState)

```swift
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserId: UUID?
    
    func login(userId: UUID) { ... }
    func logout() { ... }
}
```

### Feature State (ViewModels)

```swift
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
}
```

### View State (@State, @Binding)

```swift
struct ChatView: View {
    @State private var messageText = ""
    @State private var showImagePicker = false
}
```

---

## 🎨 UI Architecture

### SwiftUI Component Hierarchy

```
App
├── ContentView
│   ├── MainTabView (authenticated)
│   │   ├── ChatListView
│   │   │   └── ChatDetailView
│   │   └── SettingsView
│   │       ├── EditProfileView
│   │       └── EncryptionInfoView
│   └── LoginView (unauthenticated)
│       └── VerificationView
```

### Reusable Components

- `AnimatedCharacters.swift` - Loading animations
- `PikachuAnimationView.swift` - Branding
- `AvatarView` - User avatars
- `ChatRow` - Chat list items

---

## 🧪 Testing Strategy

### Unit Tests (Planned)

```swift
@testable import MelChat

final class SimpleEncryptionTests: XCTestCase {
    func testEncryptDecrypt() async throws {
        // Test encryption/decryption
    }
}
```

### Integration Tests (Planned)

```swift
final class APIClientTests: XCTestCase {
    func testSendMessage() async throws {
        // Test API communication
    }
}
```

### UI Tests (Planned)

```swift
final class ChatFlowTests: XCTestCase {
    func testSendMessage() throws {
        // Test user flow
    }
}
```

---

## 📊 Performance Considerations

### Optimization Strategies

1. **SwiftData Query Optimization**
   - Use predicates for filtering
   - Fetch only needed properties
   - Pagination for large datasets

2. **Image Handling**
   - Compression (JPEG 0.7 quality)
   - Async loading
   - Cache management

3. **Network Efficiency**
   - Request batching
   - Response caching
   - Connection pooling

4. **Memory Management**
   - `[weak self]` in closures
   - Proper deinit cleanup
   - @MainActor isolation

---

## 🔮 Future Enhancements

### Phase 2 (Next Sprint)

- [ ] Group messaging
- [ ] Voice messages
- [ ] Image/video sharing
- [ ] Push notifications
- [ ] Typing indicators

### Phase 3 (Q2 2026)

- [ ] Video calls
- [ ] Disappearing messages
- [ ] Message reactions
- [ ] Full backup/restore

---

## 📚 Tech Stack

### Core Technologies

- **Language:** Swift 6
- **UI Framework:** SwiftUI
- **Database:** SwiftData
- **Networking:** URLSession + WebSocket
- **Encryption:** CryptoKit (Curve25519 + AES-GCM)
- **Storage:** Keychain + iCloud

### Minimum Requirements

- **iOS:** 17.0+
- **Xcode:** 15.0+
- **Swift:** 6.0+

---

## 🚀 Getting Started

### For New Developers

1. **Read this file** (ARCHITECTURE.md)
2. **Check SERVICES_REGISTRY.md** before coding
3. **Follow PROJECT_STRUCTURE.md** for setup
4. **Run the app** and explore

### Key Files to Understand

```
Priority 1 (Core):
- MelChatApp.swift
- AppState.swift
- APIClient.swift
- SimpleEncryption.swift

Priority 2 (Features):
- AuthViewModel.swift
- ChatViewModel.swift
- Models.swift

Priority 3 (UI):
- AuthViews.swift
- ChatViews.swift
- ContentView.swift
```

---

## ✅ Code Quality Standards

### Swift Style Guide

- Use `async/await` (not Combine/Dispatch)
- Use `@MainActor` for UI code
- Use `[weak self]` in closures
- Error handling with `do-catch`
- Explicit types when ambiguous

### Documentation

- Document all public APIs
- Update SERVICES_REGISTRY.md
- Add TODO comments for future work
- Use MARK comments for organization

---

## 🐛 Debugging Tools

### Network Logging

```swift
NetworkLogger.shared.log("Message", group: "Auth")
```

**View logs:** Shake device → Network Logs

### SwiftData Debugging

```swift
print("✅ Loaded \(messages.count) messages")
```

### Xcode Console

- Filter by "🔐" for encryption logs
- Filter by "📡" for network logs
- Filter by "💾" for storage logs

---

**Status: ✅ UP TO DATE**

For service details, see: `SERVICES_REGISTRY.md`  
For project setup, see: `PROJECT_STRUCTURE.md`
