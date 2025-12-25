# MelChat iOS

Privacy-first, end-to-end encrypted messaging app for iOS.

## 🎯 Current Status

**Version:** 1.0.0 (MVP)
**iOS Target:** iOS 17.0+
**Swift:** Swift 6
**Architecture:** MVVM + SwiftUI + SwiftData

### ✅ Implemented Features

- **Authentication**
  - Email verification (6-digit code)
  - JWT token management
  - Keychain storage
  - Auto key generation on signup

- **End-to-End Encryption**
  - Signal Protocol-inspired implementation
  - Curve25519 key agreement
  - AES-GCM-256 encryption
  - Perfect forward secrecy (one-time prekeys)
  - Session key caching

- **Messaging**
  - One-to-one chat
  - Message encryption/decryption
  - Message status indicators (sent/delivered/read)
  - Typing indicators (UI ready)
  - Message polling (5-second interval)

- **Modern UX**
  - Haptic feedback throughout
  - Smooth animations (fade-in, scale, auto-scroll)
  - Relative timestamps ("Just now", "5m ago")
  - Pull-to-refresh
  - Search functionality
  - Empty states

- **UI Components**
  - Modern login/signup screens
  - Chat list with online status
  - Chat detail view
  - Avatar system (initials + consistent colors)
  - Settings screen (basic)
  - Image picker (ready for media sharing)

### ⏳ Pending Features

- Message persistence (SwiftData integration)
- Media sharing (image upload)
- Voice messages
- Group chat UI
- WebSocket real-time messaging
- Push notifications
- Advanced settings

## 📁 Project Structure

```
MelChat/
├── MelChat/
│   ├── App/
│   │   ├── MelChatApp.swift          # App entry point
│   │   └── AppState.swift            # Global app state
│   │
│   ├── Core/
│   │   ├── Encryption/
│   │   │   ├── EncryptionManager.swift    # E2E encryption
│   │   │   └── KeychainManager.swift      # Secure key storage
│   │   │
│   │   ├── Network/
│   │   │   ├── APIClient.swift            # REST API client
│   │   │   ├── NetworkLogger.swift        # Network debugging
│   │   │   └── WebSocketManager.swift     # WebSocket (disabled)
│   │   │
│   │   ├── Storage/
│   │   │   └── Models/
│   │   │       └── Models.swift           # SwiftData models
│   │   │
│   │   └── Utils/
│   │       ├── HapticManager.swift        # Haptic feedback
│   │       └── DateExtensions.swift       # Relative time
│   │
│   ├── Features/
│   │   ├── Auth/
│   │   │   ├── Views/
│   │   │   │   └── AuthViews.swift        # Login/signup screens
│   │   │   └── ViewModels/
│   │   │       └── AuthViewModel.swift
│   │   │
│   │   ├── Chat/
│   │   │   ├── Views/
│   │   │   │   ├── ChatViews.swift        # Chat list & detail
│   │   │   │   ├── TypingIndicatorView.swift
│   │   │   │   └── ImagePickerView.swift
│   │   │   └── ViewModels/
│   │   │       ├── ChatListViewModel.swift
│   │   │       └── ChatViewModel.swift
│   │   │
│   │   └── Settings/
│   │       ├── Views/
│   │       │   └── SettingsView.swift
│   │       └── ViewModels/
│   │           └── SettingsViewModel.swift
│   │
│   └── UI/
│       └── AvatarView.swift              # Reusable avatar component
│
└── Documentation/
    ├── iOS_ROADMAP.md                    # Development roadmap
    ├── iOS_TASKS.md                      # Current tasks
    └── XCODE_SETUP.md                    # Setup instructions
```

## 🚀 Getting Started

### Prerequisites

- Xcode 15+
- iOS 17+ device or simulator
- Backend server running (see backend repo)

### Backend Setup

The iOS app expects the backend to be running at:
- **Simulator:** `http://localhost:3000`
- **Real Device:** `http://192.168.1.116:3000` (your Mac's IP)

See `APIClient.swift` to change the backend URL.

### Build & Run

1. Open `MelChat.xcodeproj` in Xcode
2. Select target device (iPhone 15 simulator recommended)
3. Press `⌘ + R` to build and run

### First Launch

1. App will show login screen
2. Enter email → receive 6-digit code
3. Enter code → encryption keys auto-generated
4. You're in! Start chatting

## 🔐 Security Features

### End-to-End Encryption

**Key Generation:**
- Curve25519 identity key (long-term)
- Signed prekey (rotated periodically)
- 100 one-time prekeys (perfect forward secrecy)

**Message Encryption:**
- ECDH key agreement
- HKDF key derivation
- AES-GCM-256 encryption
- Session key caching

**Key Storage:**
- All private keys stored in iOS Keychain
- `kSecAttrAccessibleAfterFirstUnlock` protection
- Public keys uploaded to server

### Authentication

- Email verification (no password required for MVP)
- JWT tokens stored in Keychain
- Automatic token refresh (TODO)

## 📱 Key Components

### EncryptionManager

Singleton managing all encryption operations:

```swift
// Generate keys (on signup)
try EncryptionManager.shared.generateKeys()

// Encrypt message
let encrypted = try await EncryptionManager.shared.encrypt(
    message: "Hello",
    for: recipientUserId,
    token: authToken
)

// Decrypt message
let plaintext = try await EncryptionManager.shared.decrypt(
    encryptedMessage: encrypted,
    from: senderUserId,
    token: authToken
)
```

### HapticManager

Simple haptic feedback:

```swift
HapticManager.shared.light()    // Button taps
HapticManager.shared.medium()   // Message sent
HapticManager.shared.success()  // Operation complete
HapticManager.shared.error()    // Error occurred
```

### APIClient

REST API communication:

```swift
// Send encrypted message
let response = try await APIClient.shared.sendMessage(
    token: token,
    toUserId: recipientId,
    encryptedPayload: ciphertext
)

// Poll for new messages
let messages = try await APIClient.shared.pollMessages(token: token)
```

## 🎨 UI/UX Features

### Haptic Feedback
- Light haptics on button taps
- Medium haptics on message send
- Success/error feedback

### Smooth Animations
- Fade-in + scale transitions for new messages
- Auto-scroll to latest message
- Typing indicator animations

### Relative Timestamps
- "Just now" (< 1 min)
- "5m ago" (< 1 hour)
- "2h ago" (< 24 hours)
- "Yesterday"
- "Dec 20" (older)

## 🧪 Testing

### Manual Testing Checklist

- [ ] User signup flow
- [ ] Email verification
- [ ] Key generation
- [ ] Send message (encrypted)
- [ ] Receive message (decrypted)
- [ ] Message status updates
- [ ] Haptic feedback
- [ ] Animations
- [ ] Search
- [ ] Pull to refresh

### Known Issues

1. **Messages not persisted** - Lost on app restart (SwiftData integration pending)
2. **No media sharing** - ImagePicker UI ready, upload pending
3. **Polling inefficient** - WebSocket disabled, using 5-second polling
4. **No typing events** - UI ready, backend events missing

## 📋 Next Steps

See [iOS_TASKS.md](Documentation/iOS_TASKS.md) for detailed task list.

**High Priority:**
1. SwiftData message persistence (2 hours)
2. Message decryption display in UI (1 hour)
3. Media upload integration (3 hours)

**Medium Priority:**
4. WebSocket real-time messaging (4 hours)
5. Voice messages (1 day)
6. Settings screen completion (2 hours)

**Low Priority:**
7. Group chat UI (2 days)
8. Push notifications (1 day)
9. Advanced features (reactions, search, etc.)

## 🔧 Configuration

### Backend URL

Edit `APIClient.swift`:

```swift
#if targetEnvironment(simulator)
private let baseURL = "http://localhost:3000/api"
#else
private let baseURL = "http://YOUR_MAC_IP:3000/api"
#endif
```

### Encryption

All encryption settings in `EncryptionManager.swift`. Currently using:
- **Curve25519** for key agreement
- **AES-GCM-256** for message encryption
- **HKDF-SHA256** for key derivation

## 📞 Support

For issues or questions:
- Check [iOS_TASKS.md](Documentation/iOS_TASKS.md)
- See error logs in Xcode console
- All network requests logged via `NetworkLogger`

## 📄 License

Private project - All rights reserved

---

**Built with ❤️ using Swift & SwiftUI**
**Privacy-first • End-to-end encrypted • Modern iOS design**
