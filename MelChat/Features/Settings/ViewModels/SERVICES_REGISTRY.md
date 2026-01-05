# 📚 SERVICES REGISTRY - Single Source of Truth

> **Purpose:** This document lists ALL services in the app. Check here BEFORE creating new services to avoid duplicates.

Last Updated: 2026-01-05

---

## 🔐 Security Services

### SimpleEncryption
**File:** `Core/Encryption/SimpleEncryption.swift`  
**Type:** Singleton (`@MainActor class`)  
**Access:** `SimpleEncryption.shared`  
**Status:** ✅ ACTIVE

**Purpose:** End-to-end encryption using Curve25519 + AES-GCM

**Usage:**
```swift
// Generate keys (new user)
let publicKey = SimpleEncryption.shared.generateKeys()

// Encrypt message
let ciphertext = try SimpleEncryption.shared.encrypt(
    message: "Hello",
    recipientPublicKey: publicKey
)

// Decrypt message
let plaintext = try SimpleEncryption.shared.decrypt(
    ciphertext: ciphertext,
    senderPublicKey: publicKey
)

// Check if keys exist
let hasKeys = SimpleEncryption.shared.hasKeys()
```

**⚠️ DEPRECATED (DO NOT USE):**
- ~~`SignalProtocolManager`~~ → Use `SimpleEncryption`
- ~~`DoubleRatchetManager`~~ → Use `SimpleEncryption`
- ~~`EncryptionService`~~ → Use `SimpleEncryption`
- ~~`EncryptionManager`~~ → Use `SimpleEncryption`

---

### KeychainHelper
**File:** `KeychainHelper.swift` (should move to `Core/Security/`)  
**Type:** Class (not singleton - create instance)  
**Access:** `let helper = KeychainHelper()`  
**Status:** ✅ ACTIVE

**Purpose:** Secure keychain storage with iCloud sync support

**Usage:**
```swift
let keychainHelper = KeychainHelper()

// Save
try keychainHelper.save(
    data,
    forKey: "my.key"
)

// Load
let data = try keychainHelper.load(forKey: "my.key")

// Delete
try keychainHelper.delete(forKey: "my.key")
```

**Keys:**
```swift
KeychainHelper.Keys.authToken
KeychainHelper.Keys.privateKey
KeychainHelper.Keys.publicKey
```

---

### TokenManager
**File:** `Core/Network/TokenManager.swift`  
**Type:** Singleton (`@MainActor class`)  
**Access:** `TokenManager.shared`  
**Status:** ✅ ACTIVE

**Purpose:** JWT token management with auto-refresh

**Usage:**
```swift
// Save tokens
try TokenManager.shared.saveTokens(
    accessToken: "...",
    refreshToken: "...",
    expiresIn: 3600
)

// Get access token (auto-refreshes if needed)
let token = try await TokenManager.shared.getAccessToken()

// Logout
try await TokenManager.shared.logout()
```

---

## 🌐 Networking Services

### APIClient
**File:** `Core/Network/APIClient.swift`  
**Type:** Singleton (class)  
**Access:** `APIClient.shared`  
**Status:** ✅ ACTIVE

**Purpose:** REST API communication

**Usage:**
```swift
// Send verification code
let response = try await APIClient.shared.sendVerificationCode(email: "...")

// Upload public key
try await APIClient.shared.uploadPublicKey(publicKey: "...")

// Get user's public key
let publicKey = try await APIClient.shared.getPublicKey(userId: "...")

// Send encrypted message
let response = try await APIClient.shared.sendEncryptedMessage(
    toUserId: "...",
    encryptedMessage: ciphertext
)

// Poll messages
let messages = try await APIClient.shared.pollMessages()
```

---

### WebSocketManager
**File:** `Core/Network/WebSocketManager.swift`  
**Type:** Singleton (class)  
**Access:** `WebSocketManager.shared`  
**Status:** ✅ ACTIVE

**Purpose:** Real-time messaging via WebSocket

**Usage:**
```swift
// Connect
WebSocketManager.shared.connect(userId: "...")

// Disconnect
WebSocketManager.shared.disconnect()

// Listen for messages
WebSocketManager.shared.$receivedMessages
    .sink { messages in
        // Handle new messages
    }
```

---

### NetworkLogger
**File:** `Core/Network/NetworkLogger.swift`  
**Type:** Singleton (`@MainActor class`)  
**Access:** `NetworkLogger.shared`  
**Status:** ✅ ACTIVE

**Purpose:** Network request/response logging for debugging

**Usage:**
```swift
NetworkLogger.shared.log("Message", group: "Auth")
NetworkLogger.shared.logRequest(request, body: body)
NetworkLogger.shared.logResponse(response, data: data)
```

---

### MessageReceiver
**File:** `Core/Network/MessageReceiver.swift`  
**Type:** Singleton (`@MainActor class`)  
**Access:** `MessageReceiver.shared`  
**Status:** ✅ ACTIVE

**Purpose:** Handles receiving and decrypting incoming messages

**Usage:**
```swift
// Configure with SwiftData context
MessageReceiver.shared.configure(
    modelContext: modelContext,
    currentUserId: userId
)

// Process offline messages
await MessageReceiver.shared.processOfflineMessages(messages, modelContext: context)
```

---

## 💾 Storage Services

### Models.swift
**File:** `Core/Storage/Models/Models.swift`  
**Type:** SwiftData Models  
**Status:** ✅ ACTIVE

**Purpose:** All SwiftData models in ONE file

**Models:**
```swift
@Model class User { ... }
@Model class Message { ... }
@Model class Chat { ... }
@Model class Group { ... }
```

**⚠️ NEVER create separate model files! All models go in this file.**

---

## 🎨 UI Utilities

### HapticManager
**File:** `Core/Utilities/HapticManager.swift`  
**Type:** Singleton (class)  
**Access:** `HapticManager.shared`  
**Status:** ✅ ACTIVE

**Purpose:** Haptic feedback

**Usage:**
```swift
HapticManager.shared.light()
HapticManager.shared.medium()
HapticManager.shared.heavy()
HapticManager.shared.success()
HapticManager.shared.error()
HapticManager.shared.warning()
```

---

### VoiceRecorder
**File:** `Core/Utilities/VoiceRecorder.swift`  
**Type:** ObservableObject (`@MainActor class`)  
**Status:** ✅ ACTIVE

**Purpose:** Voice message recording and playback

**Usage:**
```swift
let recorder = VoiceRecorder()

// Start recording
let success = await recorder.startRecording()

// Stop recording
let url = recorder.stopRecording()

// Play audio
recorder.playAudio(from: url)
```

---

## 🎯 Feature ViewModels

### AuthViewModel
**File:** `Features/Auth/ViewModels/AuthViewModel.swift`  
**Type:** ObservableObject (`@MainActor class`)  
**Status:** ✅ ACTIVE

**Purpose:** Authentication logic (login, signup, verification)

---

### ChatViewModel
**File:** `Features/Chat/ViewModels/ChatViewModel.swift`  
**Type:** ObservableObject (`@MainActor class`)  
**Status:** ✅ ACTIVE

**Purpose:** Individual chat screen logic

---

### ChatListViewModel
**File:** `Features/Chat/ViewModels/ChatListViewModel.swift`  
**Type:** ObservableObject (`@MainActor class`)  
**Status:** ✅ ACTIVE

**Purpose:** Chat list screen logic with polling

---

### SettingsViewModel
**File:** `Features/Settings/ViewModels/SettingsViewModel.swift`  
**Type:** ObservableObject (`@MainActor class`)  
**Status:** ✅ ACTIVE

**Purpose:** Settings screen logic

---

## 📋 Developer Guidelines

### ✅ Before Creating a New Service:

1. **Check this registry first!**
2. Does a similar service already exist?
3. Can you extend existing service instead?
4. Is it truly needed?

### ✅ When Adding a New Service:

1. Choose correct location:
   - Networking → `Core/Networking/`
   - Security → `Core/Security/`
   - Storage → `Core/Storage/`
   - Utility → `Core/Utilities/`

2. Use singleton pattern if appropriate:
   ```swift
   class MyService {
       static let shared = MyService()
       private init() {}
   }
   ```

3. Add `@MainActor` if UI-related:
   ```swift
   @MainActor
   class MyService: ObservableObject {
       static let shared = MyService()
   }
   ```

4. **UPDATE THIS REGISTRY!**

### ❌ Common Mistakes:

1. ❌ Creating duplicate services
2. ❌ Creating multiple model files
3. ❌ Not checking registry first
4. ❌ Using deprecated services
5. ❌ Forgetting to update documentation

---

## 🔄 Migration Guide

### Old → New

```swift
// ❌ OLD (Deprecated)
SignalProtocolManager.shared.encrypt(...)
DoubleRatchetManager.shared.encrypt(...)

// ✅ NEW
SimpleEncryption.shared.encrypt(...)
```

```swift
// ❌ OLD (Deprecated)
uploadSignalKeys(bundle: ...)
uploadPublicKeys(bundle: ...)

// ✅ NEW
uploadPublicKey(publicKey: ...)
```

---

## 📊 Service Count

**Total Active Services: 12**

- Security: 3
- Networking: 4
- Storage: 1
- UI Utilities: 2
- ViewModels: 4

**Deprecated Services: 0** ✅

---

## ✅ Verification Checklist

Use this when reviewing code:

```
[ ] Service uses singleton pattern (if appropriate)
[ ] Service is documented in this registry
[ ] No duplicate functionality
[ ] Proper folder location
[ ] @MainActor if UI-related
[ ] Error handling present
[ ] NetworkLogger integration (if networking)
```

---

**Status: ✅ UP TO DATE**

For architecture overview, see: `ARCHITECTURE.md`  
For project structure, see: `PROJECT_STRUCTURE.md`
