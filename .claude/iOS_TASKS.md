# MelChat iOS - Development Tasks

**Last Updated:** 24 December 2024
**Current Status:** 85% MVP Complete

---

## 🚨 Critical Issues (Fix First!)

### 1. **Build Errors**
- [x] Duplicate KeychainManager.swift (FIXED)
- [ ] Verify all imports working
- [ ] Clean build folder
- [ ] Test on simulator

**Priority:** P0 (Blocker)
**Time:** 30 minutes

---

## 🔥 High Priority (This Week)

### 1. **Message Persistence (SwiftData Integration)**

**Current Issue:** Messages disappear on app restart

**Tasks:**
- [ ] Integrate SwiftData models in ChatViewModel
- [ ] Save messages locally after send/receive
- [ ] Load messages from local DB on view appear
- [ ] Implement sync logic (local + server)
- [ ] Add message deletion support

**Files to Modify:**
- `ChatViewModel.swift`
- `ChatListViewModel.swift`
- `Models.swift` (already has SwiftData models)

**Code Example:**
```swift
// In ChatViewModel
@Environment(\.modelContext) private var modelContext

func sendMessage(_ text: String) async {
    // ... existing encryption code

    // Save to SwiftData
    let message = Message(
        content: text,
        senderId: currentUserId,
        recipientId: otherUserId,
        chatId: chatId,
        isFromCurrentUser: true
    )
    modelContext.insert(message)
    try? modelContext.save()
}
```

**Priority:** P0 (Critical)
**Time:** 2-3 hours

---

### 2. **Display Decrypted Messages in UI**

**Current Issue:** Messages decrypt in background but don't show in chat

**Tasks:**
- [ ] Add decrypted messages to ChatViewModel.messages array
- [ ] Update UI to display messages
- [ ] Handle message ordering (by timestamp)
- [ ] Add animations for new messages

**Files to Modify:**
- `ChatListViewModel.swift` (handleNewMessage function)
- `ChatViewModel.swift`
- `ChatViews.swift`

**Code Example:**
```swift
// In ChatListViewModel.handleNewMessage()
let decryptedText = try await EncryptionManager.shared.decrypt(...)

// Add to messages array
let newMessage = Message(
    id: message.id,
    content: decryptedText,
    timestamp: Date(),
    isFromCurrentUser: false,
    status: .delivered
)

// Notify ChatViewModel to update UI
NotificationCenter.default.post(
    name: .newMessageReceived,
    object: newMessage
)
```

**Priority:** P0 (Critical)
**Time:** 1 hour

---

### 3. **Media Upload Integration**

**Current Status:** ImagePicker UI ready, upload pending

**Tasks:**
- [ ] Connect ImagePicker to ChatDetailView
- [ ] Compress image before upload
- [ ] Call backend media upload API
- [ ] Show upload progress
- [ ] Display image in chat bubble
- [ ] Add image viewer (tap to fullscreen)

**Files to Modify:**
- `ChatViews.swift` (add photo button)
- `ImagePickerView.swift` (connect to upload)
- `APIClient.swift` (add media upload endpoint)

**New Files:**
- `MediaMessageBubble.swift` (display images in chat)
- `ImageViewer.swift` (fullscreen image view)

**Priority:** P1 (High)
**Time:** 3-4 hours

---

## 📱 Medium Priority (Next 1-2 Weeks)

### 4. **Settings Screen Completion**

**Tasks:**
- [ ] Complete profile editing UI
- [ ] Add avatar upload
- [ ] Connect to backend profile API
- [ ] Add privacy settings toggle
- [ ] Display current encryption status
- [ ] Add about/help section

**Files to Modify:**
- `SettingsView.swift`
- `SettingsViewModel.swift`
- `APIClient.swift` (profile endpoints)

**Priority:** P1 (High)
**Time:** 2-3 hours

---

### 5. **WebSocket Real-Time Messaging**

**Current Issue:** Using inefficient polling (5-second intervals)

**Tasks:**
- [ ] Fix WebSocket port conflict (or use different port)
- [ ] Re-enable WebSocketManager
- [ ] Replace polling with WebSocket listeners
- [ ] Implement typing events
- [ ] Add presence tracking (online/offline)
- [ ] Handle reconnection logic

**Files to Modify:**
- `WebSocketManager.swift`
- `ChatListViewModel.swift` (remove polling)
- `ChatViewModel.swift` (add typing events)

**Priority:** P2 (Medium)
**Time:** 4-5 hours

---

### 6. **Voice Messages**

**Tasks:**
- [ ] Add microphone permission request
- [ ] Implement audio recording (AVFoundation)
- [ ] Create waveform visualization
- [ ] Add audio compression (AAC)
- [ ] Upload to media service
- [ ] Create voice message bubble UI
- [ ] Implement audio playback
- [ ] Add playback controls (play/pause, speed)

**New Files:**
- `VoiceRecorder.swift`
- `WaveformView.swift`
- `AudioPlayer.swift`
- `VoiceMessageBubble.swift`

**Priority:** P2 (Medium)
**Time:** 1 day

---

## 🎨 UI/UX Improvements

### 7. **Skeleton Loading States**

**Tasks:**
- [ ] Add skeleton screens for chat list
- [ ] Add skeleton for message loading
- [ ] Implement shimmer effect
- [ ] Show loading state during encryption

**New Files:**
- `SkeletonView.swift`

**Priority:** P3 (Low)
**Time:** 2 hours

---

### 8. **Message Reactions**

**Tasks:**
- [ ] Long-press gesture on message bubble
- [ ] Show emoji picker
- [ ] Send reaction to backend
- [ ] Display reactions under messages
- [ ] Animate reaction additions

**Priority:** P3 (Low)
**Time:** 3-4 hours

---

### 9. **Swipe Actions**

**Tasks:**
- [ ] Swipe to reply
- [ ] Swipe to delete
- [ ] Add contextual menu

**Priority:** P3 (Low)
**Time:** 2 hours

---

## 👥 Group Chat Features

### 10. **Group Chat UI**

**Tasks:**
- [ ] Create group creation flow
- [ ] Add member selection UI
- [ ] Implement group settings
- [ ] Display group info
- [ ] Show participant list
- [ ] Handle group messages
- [ ] Add group encryption (shared key)

**New Files:**
- `GroupChatView.swift`
- `CreateGroupView.swift`
- `GroupMembersView.swift`
- `GroupViewModel.swift`

**Priority:** P2 (Medium)
**Time:** 2 days

---

## 🔔 Push Notifications

### 11. **Push Notification Support**

**Tasks:**
- [ ] Request notification permissions
- [ ] Register for remote notifications
- [ ] Send device token to backend
- [ ] Handle notification taps
- [ ] Update badge count
- [ ] Add notification settings in Settings

**Files to Modify:**
- `MelChatApp.swift`
- `SettingsView.swift`

**New Files:**
- `NotificationManager.swift`

**Priority:** P2 (Medium)
**Time:** 1 day

---

## 🔒 Security Enhancements

### 12. **Key Verification UI**

**Tasks:**
- [ ] Add QR code generation for identity key
- [ ] Implement QR scanner
- [ ] Show security code comparison
- [ ] Mark contacts as verified
- [ ] Warn on unverified contacts

**Priority:** P3 (Low)
**Time:** 1 day

---

### 13. **Key Rotation**

**Tasks:**
- [ ] Auto-rotate signed prekeys (every 30 days)
- [ ] Replenish one-time prekeys when low (<20)
- [ ] Implement key rotation UI

**Priority:** P3 (Low)
**Time:** 3-4 hours

---

## 🧪 Testing & Quality

### 14. **Unit Tests**

**Tasks:**
- [ ] Write tests for EncryptionManager
- [ ] Write tests for ViewModels
- [ ] Write tests for APIClient
- [ ] Add UI tests for critical flows

**Priority:** P2 (Medium)
**Time:** 2 days

---

### 15. **Error Handling**

**Tasks:**
- [ ] Improve error messages
- [ ] Add retry logic for failed messages
- [ ] Handle network errors gracefully
- [ ] Add offline mode indicator

**Priority:** P2 (Medium)
**Time:** 1 day

---

## 📦 Production Prep

### 16. **App Store Preparation**

**Tasks:**
- [ ] Create app icon (all sizes)
- [ ] Take screenshots (all device sizes)
- [ ] Write App Store description
- [ ] Create privacy policy
- [ ] Create terms of service
- [ ] Set up TestFlight beta
- [ ] Submit to App Store Review

**Priority:** P1 (High, when ready)
**Time:** 1 week

---

## 📊 Progress Tracking

### Overall Progress: 85%

**Completed:**
- [x] Authentication (100%)
- [x] E2E Encryption (100%)
- [x] Basic Messaging (90%)
- [x] Modern UI (95%)
- [x] UX Polish (90%)

**In Progress:**
- [ ] Message Persistence (0%)
- [ ] Media Sharing (30%)

**Not Started:**
- [ ] Voice Messages (0%)
- [ ] Group Chat (0%)
- [ ] WebSocket (0%)
- [ ] Push Notifications (0%)

---

## 🎯 Sprint Planning

### Sprint 1 (This Week)
- [ ] Fix build errors
- [ ] Message persistence
- [ ] Display decrypted messages
- [ ] Media upload integration

### Sprint 2 (Next Week)
- [ ] Settings completion
- [ ] WebSocket real-time
- [ ] Voice messages (start)

### Sprint 3 (Week 3)
- [ ] Voice messages (complete)
- [ ] Group chat
- [ ] Push notifications

### Sprint 4 (Week 4)
- [ ] Testing & bug fixes
- [ ] App Store prep
- [ ] Beta testing

---

## 💡 Tips for Xcode Development

### Common Issues

**Build Errors:**
```bash
# Clean build folder
⌘ + Shift + K

# Clean derived data
⌘ + Shift + Option + K
```

**SwiftData Issues:**
```swift
// Always provide modelContainer in Preview
#Preview {
    ChatListView()
        .modelContainer(for: [Message.self, Chat.self, User.self])
        .environmentObject(AppState())
}
```

**Network Debugging:**
```swift
// Enable detailed network logs
NetworkLogger.shared.log("🔍 Request: \(request)")
```

---

## 📞 Need Help?

**Common Questions:**

**Q: How do I test encryption?**
A: Use 2 different simulator devices or 1 simulator + 1 real device

**Q: Backend not responding?**
A: Check if server is running on `http://192.168.1.116:3000`

**Q: Messages not showing?**
A: Check ChatListViewModel.handleNewMessage() is being called

**Q: Build failing?**
A: Clean build folder (⌘+Shift+K) and restart Xcode

---

**Ready to build!** 🚀

Start with the Critical Issues section and work your way down.
Use Xcode's issue navigator (⌘+5) to track build errors.
Test frequently on simulator and real device.
