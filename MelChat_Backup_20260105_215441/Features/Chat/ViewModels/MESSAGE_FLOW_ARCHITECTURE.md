# Message Flow Architecture

## Data Structure Alignment

### Before Fix ❌
```
Backend JSON                    iOS Code
-------------                   --------
{                               struct OfflineMessage {
  "encryptedPayload": {           let payload: String  ❌ TYPE MISMATCH
    "ciphertext": "...",        }
    "ratchetPublicKey": "...",
    "chainLength": 1
  }
}
```

### After Fix ✅
```
Backend JSON                    iOS Code
-------------                   --------
{                               struct OfflineMessage {
  "encryptedPayload": {           let encryptedPayload: EncryptedPayload  ✅ MATCHES
    "ciphertext": "...",        }
    "ratchetPublicKey": "...",
    "chainLength": 1,           struct EncryptedPayload {
    "previousChainLength": 0      let ciphertext: String
  }                                 let ratchetPublicKey: String
}                                   let chainLength: Int
                                    let previousChainLength: Int
                                }
```

---

## Message Flow Diagram

### Real-Time Messages (WebSocket)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MESSAGE FLOW                                │
└─────────────────────────────────────────────────────────────────────┘

    Backend Server                         iOS App
    ──────────────                         ───────
         │
         │  1. Send Message via WebSocket
         ├────────────────────────────────────────►
         │                                         │
         │  JSON:                                  │  WebSocketManager
         │  {                                      │  ─────────────────
         │    "type": "new_message",               │  • Receives WS message
         │    "message": {                         │  • Parses JSON
         │      "id": "msg-123",                   │  • Decodes to ReceivedMessage
         │      "from": "user-456",                │
         │      "to": "user-789",                  ▼
         │      "encryptedPayload": {              │
         │        "ciphertext": "base64...",       │  MessageReceiver
         │        "ratchetPublicKey": "...",       │  ───────────────
         │        "chainLength": 1,                │  • Listens via Combine
         │        "previousChainLength": 0         │  • Converts to EncryptedMessagePayload
         │      },                                 │
         │      "timestamp": "2025-12-27T..."      ▼
         │    }
         │  }                                      │  SignalProtocolManager
         │                                         │  ──────────────────────
         │                                         │  • Decrypts with Double Ratchet
         │                                         │  • Returns plaintext string
         │                                         │
         │                                         ▼
         │
         │  2. Send ACK (delivered/failed)        │  MessageReceiver
         ◄────────────────────────────────────────┤  ───────────────
         │                                         │  • Saves to SwiftData (TODO)
         │  JSON:                                  │  • Posts notification
         │  {                                      │
         │    "type": "ack",                       ▼
         │    "messageId": "msg-123",
         │    "status": "delivered"                │  NotificationCenter
         │  }                                      │  ──────────────────
         │                                         │  • Posts "NewMessageReceived"
         │                                         │
         │                                         ▼
         │
         │                                         │  ChatViewModel
         │                                         │  ──────────────
         │                                         │  • Receives notification
         │                                         │  • Updates UI with new message
         │                                         │
```

---

### Polling Messages (HTTP API)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      POLLING FLOW (Every 30s)                       │
└─────────────────────────────────────────────────────────────────────┘

    Backend Server                         iOS App
    ──────────────                         ───────
         │
         │  1. Poll for new messages
         ◄────────────────────────────────────────┤
         │                                         │  ChatListViewModel
         │  GET /api/messages/poll                 │  ──────────────────
         │  Authorization: Bearer <token>          │  • Timer fires every 30s
         │                                         │  • Calls pollMessages()
         │                                         │
         │  2. Return offline messages             │
         ├────────────────────────────────────────►│
         │                                         │
         │  JSON Response:                         │  APIClient
         │  {                                      │  ──────────
         │    "success": true,                     │  • Receives HTTP response
         │    "messages": [                        │  • Decodes to PollMessagesResponse
         │      {                                  │  • Returns [OfflineMessage]
         │        "id": "msg-789",                 │
         │        "from": "user-100",              ▼
         │        "to": "user-789",
         │        "encryptedPayload": {            │  ChatListViewModel
         │          "ciphertext": "...",           │  ──────────────────
         │          "ratchetPublicKey": "...",     │  • Loops through messages
         │          "chainLength": 2,              │  • Calls handleNewMessage()
         │          "previousChainLength": 1       │
         │        },                               ▼
         │        "timestamp": "2025-12-27T..."
         │      }                                  │  SignalProtocolManager
         │    ]                                    │  ──────────────────────
         │  }                                      │  • Converts to EncryptedMessagePayload
         │                                         │  • Decrypts message
         │                                         │  • Returns plaintext
         │                                         │
         │                                         ▼
         │
         │  3. Send ACK for each message          │  ChatListViewModel
         ◄────────────────────────────────────────┤  ──────────────────
         │                                         │  • Saves to SwiftData
         │  POST /api/messages/ack                 │  • Sends ACK to backend
         │  { "messageId": "...",                  │  • Posts notification
         │    "status": "delivered" }              │
         │                                         ▼
         │
         │                                         │  ChatView
         │                                         │  ────────
         │                                         │  • Receives notification
         │                                         │  • Updates message list
         │                                         │
```

---

## Key Components

### 1. Data Models

```swift
// Network layer (APIClient, WebSocket)
struct EncryptedPayload: Codable {
    let ciphertext: String
    let ratchetPublicKey: String
    let chainLength: Int
    let previousChainLength: Int
}

// Signal Protocol layer
struct EncryptedMessagePayload: Codable {
    let ciphertext: String
    let ratchetPublicKey: String
    let chainLength: Int
    let previousChainLength: Int
}

// These are structurally identical!
// EncryptedPayload = network format
// EncryptedMessagePayload = crypto format
```

### 2. Conversion Pattern

```swift
// When receiving from network → convert to crypto format
let cryptoPayload = EncryptedMessagePayload(
    ciphertext: networkPayload.ciphertext,
    ratchetPublicKey: networkPayload.ratchetPublicKey,
    chainLength: networkPayload.chainLength,
    previousChainLength: networkPayload.previousChainLength
)

// Then decrypt
let plaintext = try await SignalProtocolManager.shared.decrypt(
    payload: cryptoPayload,
    from: senderId
)
```

### 3. Message Lifecycle

```
┌──────────────┐
│   Backend    │
│   Sends      │
│  Encrypted   │
│   Message    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  WebSocket   │
│     or       │  ← Receives encrypted message
│  HTTP Poll   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Decode     │  ← Parse JSON to EncryptedPayload
│     JSON     │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Convert    │  ← EncryptedPayload → EncryptedMessagePayload
│   Format     │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Decrypt    │  ← Signal Protocol Double Ratchet
│   Message    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│     Save     │  ← SwiftData + Notification
│   & Display  │
└──────────────┘
```

---

## Error Handling

### Decryption Failure
```
MessageReceiver → Decrypt fails
                ↓
             Send ACK("failed")
                ↓
             Log error
                ↓
          Don't crash app
```

### Network Failure
```
Poll/WebSocket → Connection fails
                ↓
             Retry with backoff
                ↓
          Show user warning
                ↓
        Messages queued on server
```

### Invalid Format
```
JSON decode → Fails to parse
            ↓
         Log error
            ↓
       Skip message
            ↓
    Don't send ACK (server will retry)
```

---

## Testing Scenarios

### ✅ Happy Path
1. User A sends message to User B
2. Backend encrypts and stores
3. User B polls or receives via WebSocket
4. iOS decrypts successfully
5. Message appears in chat
6. ACK sent to backend

### ⚠️ Edge Cases
1. **Offline then online**: Poll endpoint returns queued messages
2. **Decryption fails**: Send "failed" ACK, log error
3. **Network interruption**: WebSocket reconnects, poll continues
4. **Duplicate messages**: Check message ID before adding to UI

---

## Performance Considerations

### Batching
- Poll returns up to 100 messages at once
- Process in background thread
- Update UI on main thread

### Caching
- Signal Protocol sessions cached in memory
- Keys stored in Keychain (secure)
- Messages stored in SwiftData (persistent)

### Network Efficiency
- WebSocket preferred (real-time, low latency)
- Polling as fallback (30s interval)
- Only ACK once per message (idempotent)

---

## Security Notes

### End-to-End Encryption
- Messages encrypted with Signal Protocol
- Server cannot read message content
- Only sender and recipient have keys

### Forward Secrecy
- Each message uses new ephemeral key
- Past messages safe even if current key compromised
- Ratchet advances with each message

### Authentication
- Access token in Authorization header
- Token refresh automatic
- WebSocket authenticated on connect

---

## Future Improvements

1. **Read Receipts**: Send "read" ACK when user views message
2. **Typing Indicators**: WebSocket event when user is typing
3. **Message Reactions**: Emoji reactions to messages
4. **Media Support**: Images, videos, voice messages
5. **Group Chats**: Multiple recipients, shared group keys
6. **Push Notifications**: Wake app when message arrives (offline)

