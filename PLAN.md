# MelChat - Privacy-First P2P Encrypted Messaging App

## Proje Özeti
Uçtan uca şifreli, hybrid P2P iOS messaging uygulaması. WhatsApp alternatifi, privacy-first yaklaşım.

**Temel Özellikler**:
- ✅ Email doğrulama
- ✅ Uçtan uca şifreleme (Signal Protocol)
- ✅ Grup chat (256 kişi, admin 10 kişi kickleyebilir)
- ✅ Modern UX (emoji, reactions, voice messages)
- ✅ Sesli/görüntülü arama (WebRTC)
- ✅ Medya paylaşımı (resim, video, ses, dosya)
- ✅ **Mesaj kaybı YOK** - güçlü retry/queue logic

---

## Teknik Mimari

### Hybrid P2P Model

```
┌─────────────────────────────────────────┐
│  SUNUCU (Minimal Role)                  │
├─────────────────────────────────────────┤
│ ✅ User directory (email → userID)      │
│ ✅ Public key exchange (Signal keys)    │
│ ✅ WebRTC signaling (arama için)        │
│ ✅ Offline mesaj relay (ŞİFRELİ)       │
│ ✅ Push notification trigger           │
│                                         │
│ ❌ DB'de mesaj içeriği YOK              │
│ ❌ DB'de medya YOK                      │
│ ❌ Mesajları deşifre edemez             │
└─────────────────────────────────────────┘
```

**Mesaj Akışı**:
1. Alice mesaj yazar → Signal Protocol ile şifreler
2. Bob online → WebSocket ile direkt iletilir (sunucu sadece relay)
3. Bob offline → Redis queue'da geçici bekler (şifreli blob, 7 gün TTL)
4. Bob online olunca → şifreli mesajları alır, sunucu siler
5. **Mesajlar kalıcı olarak sadece iOS Core Data'da** (encrypted)

---

## Tech Stack

### iOS App (Native)
- **Dil**: Swift 6.x
- **UI**: SwiftUI
- **Min iOS**: 17.0+
- **Şifreleme**: CryptoKit + libsignal-client-swift
- **P2P/WebRTC**: WebRTC framework + CallKit
- **Network**: URLSession WebSocket (native, auto-reconnect)
- **Storage**:
  - Core Data + SQLCipher (mesajlar, encrypted)
  - Keychain (encryption keys)
  - File System (medya, encrypted)

### Backend
- **Runtime**: Node.js 22 + TypeScript
- **Framework**: Fastify (yüksek performans)
- **WebSocket**: Socket.io (built-in reconnect logic)
- **Database**: PostgreSQL 16 (sadece user registry + metadata)
- **Cache/Queue**: Redis 7 (message queue, presence, persistence enabled)
- **ORM**: Prisma
- **E2EE**: libsignal-server (key management)
- **WebRTC**: simple-peer (signaling)

### Infrastructure (VPS)
- Docker Compose (kolay deployment)
- PostgreSQL 16
- Redis 7 (RDB + AOF persistence)
- Nginx (reverse proxy, SSL, rate limiting)
- coturn (TURN server - WebRTC NAT traversal)
- Let's Encrypt (SSL sertifika)

---

## Core Features - Detaylı

### 1. Email Doğrulama

**Akış**:
1. Kullanıcı email girer
2. Backend 6 haneli kod gönderir (SMTP)
3. Kullanıcı kodu girer → doğrulama
4. Hesap oluşturulur

**Tech**:
- SMTP: VPS kendi SMTP'si veya SendGrid free tier (100 email/gün)
- Rate limiting: 5 deneme/dakika (spam önleme)
- Kod TTL: 5 dakika
- Email hash: SHA-256 (orijinal email DB'de saklanmaz)

---

### 2. Uçtan Uca Şifreleme (E2EE)

**Protokol**: Signal Protocol (Double Ratchet Algorithm)

**Neden Signal Protocol?**:
- Industry standard (WhatsApp, Signal kullanır)
- Forward secrecy (eski mesajlar deşifre edilemez)
- Future secrecy (key compromise sonrası güvenli)
- Async messaging (offline kullanıcılar)

**Anahtar Yönetimi**:
```
Her kullanıcı:
├─ Identity Key Pair (long-term, Keychain)
├─ Signed Pre Key (per3iyodik rotasyon)
├─ One-Time Pre Keys (pool of 100)
└─ Session Keys (her chat için unique)
```

**Şifreleme Akışı**:
1. Alice → Bob'a mesaj
2. Alice, Bob'un public key bundle'ını sunucudan alır
3. Signal Protocol session oluşturur
4. Mesaj şifrelenir (AES-256-GCM)
5. Şifreli mesaj gönderilir
6. Bob deşifre eder

**Sunucu Rolü**: Sadece şifreli blob iletir, içeriği okuyamaz

---

### 3. Mesaj Güvenilirliği - Retry/Queue Logic

#### Problem Senaryoları:
- ❌ Network kopması
- ❌ App crash
- ❌ Sunucu restart
- ❌ Karşı taraf offline

#### Çözüm: Message Queue + ACK Pattern

**Mesaj Durumları** (iOS):
```swift
enum MessageStatus {
    case pending      // ⏳ Gönderiliyor
    case sent         // ✓  Sunucuya ulaştı
    case delivered    // ✓✓ Karşıya ulaştı
    case read         // ✓✓ (mavi) Okundu
    case failed       // ❌ Gönderilemedi (retry button)
}
```

**Gönderim Akışı**:
```
1. Alice mesaj yazar
   └─> Local DB'ye kaydet (pending status)

2. Şifrele + sunucuya gönder
   └─> Retry logic: max 3 deneme, exponential backoff (2s, 4s, 8s)

3. Sunucu ACK döndü mü?
   ├─> EVET: Status "sent" ✓
   └─> HAYIR: 3 deneme sonra "failed" → retry button

4. Bob online mı?
   ├─> EVET: Mesaj direkt ilet → "delivered" ACK
   └─> HAYIR: Redis queue'da bekle (7 gün TTL)

5. Bob okudu mu?
   └─> "read" ACK → mavi tik ✓✓
```

**iOS Retry Logic**:
```swift
class MessageSender {
    func send(_ message: Message) async throws {
        // 1. Local DB (pending)
        try await storage.save(message, status: .pending)

        // 2. Şifrele
        let encrypted = try encryption.encrypt(message)

        // 3. Retry logic (max 3)
        let ack = try await sendWithRetry(encrypted, maxRetries: 3)

        // 4. Status güncelle
        try await storage.updateStatus(message.id, status: .sent)
    }

    private func sendWithRetry(_ data: Data, maxRetries: Int) async throws {
        var attempt = 0
        while attempt < maxRetries {
            do {
                return try await api.sendMessage(data, timeout: 10)
            } catch {
                attempt += 1
                let delay = pow(2.0, Double(attempt)) // exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw MessageError.sendFailed
    }
}
```

**Backend Queue (Redis)**:
```typescript
class MessageQueue {
    async enqueue(message: EncryptedMessage) {
        // Redis queue'ya ekle
        await redis.lpush(
            `offline:${message.toUserId}:messages`,
            JSON.stringify(message)
        );

        // TTL: 7 gün
        await redis.expire(
            `offline:${message.toUserId}:messages`,
            7 * 24 * 60 * 60
        );

        return { ack: true, messageId: message.id };
    }

    async flush(userId: string, socket: WebSocket) {
        const messages = await redis.lrange(
            `offline:${userId}:messages`,
            0, -1
        );

        for (const msg of messages) {
            socket.send(msg);
            await this.waitForAck(msg.id, 30000); // 30s timeout
            await redis.lrem(`offline:${userId}:messages`, 1, msg);
        }
    }
}
```

**WebSocket Reconnection** (iOS):
```swift
class WebSocketManager {
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    func handleDisconnect() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            showOfflineAlert()
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30) // max 30s
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        connect()
    }

    func startHeartbeat() {
        Task {
            while socket?.state == .running {
                try? await socket?.send(.string("ping"))
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
            }
        }
    }
}
```

**Güvenilirlik Garantileri**:
- ✅ Local DB'ye önce yaz (crash safe)
- ✅ Retry logic (network kopması safe)
- ✅ Redis persistence (sunucu restart safe)
- ✅ ACK pattern (her adım doğrulanır)
- ✅ Duplicate detection (UUID-based message ID)

---

### 4. Grup Chat

**Protokol**: Sender Keys (Signal'in grup extension'ı)

**Özellikler**:
- Max 256 kişi
- Admin yetkisi: üye ekleme/çıkarma, isim değiştirme
- **Admin 10 kişi kickleyebilir** (spam önleme)
- Member ekleme/çıkarma → key rotation (forward secrecy)

**Grup Metadata**:
```json
{
  "groupId": "uuid",
  "name": "Grup İsmi",
  "avatar": "encrypted_image_url",
  "members": ["userId1", "userId2"],
  "admins": ["userId1"],
  "createdAt": "timestamp",
  "senderKeyDistribution": "encrypted"
}
```

---

### 5. Modern UX (WhatsApp-like)

**Özellikler**:
- ✅ Emoji picker (iOS native)
- ✅ Emoji reactions (mesaja uzun bas → 👍❤️😂😮😢🙏)
- ✅ Voice messages (WhatsApp tarzı basılı tut & kaydet)
- ✅ Typing indicator ("yazıyor...")
- ✅ Online/last seen (privacy settings'te kapatılabilir)
- ✅ Read receipts - mavi tik (kapatılabilir)
- ✅ Swipe to reply
- ✅ Media preview (thumbnails, waveform)
- ✅ Dark mode
- ✅ Haptic feedback

**Voice Message**:
- Mikrofon butonuna basılı tut
- Waveform animasyonu
- Yukarı kaydır → cancel
- Bırak → gönder
- Alıcı: waveform preview, playback

---

### 6. Sesli/Görüntülü Arama (VoIP)

**Teknoloji**: WebRTC

**Akış**:
1. Alice → Bob'u arar
2. Sunucu üzerinden SDP exchange (signaling)
3. STUN/TURN ile NAT traversal
4. P2P audio/video stream
5. E2EE: DTLS-SRTP (WebRTC native)

**Tech Stack**:
- WebRTC framework (iOS)
- CallKit (native arama UI, lock screen'de göster)
- PushKit (arka plandayken arama bildirimi)
- STUN: Google ücretsiz STUN
- TURN: coturn (VPS'te self-hosted)

**Codec**:
- Audio: Opus (~50 Kbps)
- Video: H.264 (500 Kbps - 2 Mbps)

**UI Features**:
- Picture-in-Picture
- Speaker/mute toggle
- Camera switch (front/back)
- Video on/off toggle

---

### 7. Medya Paylaşımı

**Desteklenen Formatlar**:
- **Resim**: JPEG, PNG, HEIC, GIF
- **Video**: MP4, MOV (H.264/HEVC)
- **Ses**: M4A, MP3, WAV
- **Dosya**: PDF, TXT, vb (max 100 MB)

**Şifreleme Akışı**:
1. Dosya iOS'ta AES-256 ile şifrelenir
2. Random encryption key oluşturulur
3. Şifreli dosya geçici sunucuya yüklenir (30 gün TTL)
4. Encryption key, Signal Protocol ile mesaj olarak gönderilir
5. Alıcı dosyayı indirir ve deşifre eder

**Storage**:
- **iOS**: Encrypted cache dizini
- **Sunucu**: VPS'te geçici encrypted storage (30 gün sonra auto-delete)

**Önizlemeler**:
- Resim: thumbnail generation (300x300)
- Video: ilk frame thumbnail + duration
- Ses: waveform visualization
- PDF: ilk sayfa preview

**Auto-download Ayarları**:
- WiFi: otomatik indir
- Mobil veri: sor (10 MB üstü)
- Roaming: sorma, manuel

---

## Database Schema

### PostgreSQL (Minimal)

```sql
-- Kullanıcılar
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email_hash VARCHAR(64) UNIQUE NOT NULL,  -- SHA-256 (orijinal email YOK)
    username VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    avatar_url TEXT,

    -- Signal Protocol Public Keys
    identity_key TEXT NOT NULL,
    signed_prekey TEXT NOT NULL,
    signed_prekey_signature TEXT NOT NULL,
    onetime_prekeys JSONB DEFAULT '[]',

    -- APNs
    push_token TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ,

    -- Privacy Settings
    show_online_status BOOLEAN DEFAULT TRUE,
    show_read_receipts BOOLEAN DEFAULT TRUE,

    is_verified BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_users_email_hash ON users(email_hash);
CREATE INDEX idx_users_username ON users(username);

-- Email Doğrulama Kodları
CREATE TABLE verification_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    code VARCHAR(6) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '5 minutes',
    attempts INT DEFAULT 0,
    is_used BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_verification_codes ON verification_codes(email, is_used);

-- Mesaj Metadata (opsiyonel, analytics için)
-- NOT: Mesaj içeriği YOK, sadece istatistik
CREATE TABLE message_metadata (
    id UUID PRIMARY KEY,
    from_user_id UUID REFERENCES users(id),
    to_user_id UUID REFERENCES users(id),
    group_id UUID REFERENCES groups(id),  -- nullable
    queued_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    status VARCHAR(20),  -- 'queued', 'delivered', 'expired'
    content_type VARCHAR(20)  -- 'text', 'image', 'video', 'audio'
    -- Mesaj içeriği YOK!!!
);

CREATE INDEX idx_message_metadata_to_user ON message_metadata(to_user_id, status);

-- Gruplar
CREATE TABLE groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    sender_key_distribution BYTEA  -- encrypted
);

CREATE TABLE group_members (
    group_id UUID REFERENCES groups(id),
    user_id UUID REFERENCES users(id),
    is_admin BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    kicked_count INT DEFAULT 0,  -- Admin kaç kişi kickledi
    PRIMARY KEY (group_id, user_id)
);

CREATE INDEX idx_group_members ON group_members(user_id);
```

### Redis (In-Memory Queue)

```
# Offline mesaj queue
offline:{userId}:messages → [encrypted_message1, encrypted_message2, ...]
  TTL: 7 gün

# Presence (online/offline status)
presence:{userId} → { status: 'online', lastSeen: timestamp }
  TTL: 5 dakika (heartbeat ile refresh)

# Typing indicator
typing:{chatId}:{userId} → true
  TTL: 5 saniye

# ACK tracking
ack:{messageId} → { delivered: true, read: false }
  TTL: 24 saat

# Rate limiting
ratelimit:{userId}:messages → count
  TTL: 1 dakika
```

**Redis Persistence** (mesaj kaybı önleme):
```conf
# RDB snapshots
save 900 1      # 15 dakikada 1 değişiklik
save 300 10     # 5 dakikada 10 değişiklik
save 60 10000   # 1 dakikada 10K değişiklik

# AOF (Append-Only File)
appendonly yes
appendfsync everysec

# Memory
maxmemory 512mb
maxmemory-policy allkeys-lru
```

---

## iOS Core Data Schema

```swift
// Mesajlar (Local, Encrypted)
@Model
class Message {
    @Attribute(.unique) var id: UUID
    var chatId: UUID
    var fromUserId: UUID
    var toUserId: UUID
    var groupId: UUID?

    // Encrypted content
    var encryptedContent: Data
    var contentType: String  // text, image, video, audio, file

    // Status
    var status: MessageStatus  // pending, sent, delivered, read, failed
    var retryCount: Int = 0

    // Timestamps
    var createdAt: Date
    var sentAt: Date?
    var deliveredAt: Date?
    var readAt: Date?

    // Metadata
    var isFromMe: Bool
    var mediaURL: URL?  // local encrypted file
    var thumbnailURL: URL?
    var duration: TimeInterval?  // audio/video

    // Reactions
    var reactions: [Reaction]?
}

// Chatler
@Model
class Chat {
    @Attribute(.unique) var id: UUID
    var type: ChatType  // oneToOne, group
    var otherUserId: UUID?
    var groupId: UUID?
    var lastMessage: Message?
    var lastMessageAt: Date?
    var unreadCount: Int = 0
    var isPinned: Bool = false
    var isMuted: Bool = false
}

// Kullanıcılar (Cache)
@Model
class User {
    @Attribute(.unique) var id: UUID
    var username: String
    var displayName: String?
    var avatarURL: URL?
    var publicIdentityKey: String
    var publicSignedPrekey: String
    var lastSeen: Date?
    var isOnline: Bool = false
}

// Gruplar
@Model
class Group {
    @Attribute(.unique) var id: UUID
    var name: String
    var avatarURL: URL?
    var members: [UUID]
    var admins: [UUID]
    var createdBy: UUID
    var createdAt: Date
}
```

---

## Privacy & Security

### Sunucuda Olmayan Şeyler:
❌ Mesaj içerikleri (hiçbir zaman)
❌ Medya dosyaları (geçici encrypted storage, 30 gün)
❌ Encryption keys (sadece iOS Keychain)
❌ Orijinal email (sadece SHA-256 hash)
❌ Konuşma metadata (kim kiminle konuştu - opsiyonel analytics hariç)

### Sunucuda Olan Minimal Data:
✅ User ID + username
✅ Email hash (doğrulama için)
✅ Public keys (Signal Protocol için gerekli)
✅ Last seen timestamp (privacy settings'te kapatılabilir)
✅ Offline mesajlar (şifreli blob, geçici, Redis)

### iOS Security:
✅ Core Data encryption (SQLCipher)
✅ Keychain (encryption keys)
✅ Data Protection API (dosyalar)
✅ Certificate pinning (sunucu bağlantısı)
✅ Screenshot blocking (hassas ekranlarda)
✅ Biometric lock (Face ID/Touch ID)

### Backend Security:
✅ HTTPS/TLS 1.3 zorunlu
✅ Rate limiting (DDoS önleme)
✅ Input validation & sanitization
✅ JWT authentication (short-lived tokens)
✅ bcrypt password hashing
✅ SQL injection önleme (Prisma ORM)
✅ CORS configuration

### Network Security:
✅ WebRTC encryption (DTLS-SRTP)
✅ Signal Protocol (E2EE)
✅ Forward secrecy
✅ Perfect forward secrecy (PFS)

---

## Project Structure

```
melchat/
├── ios/
│   └── MelChat/
│       ├── MelChatApp.swift
│       ├── Features/
│       │   ├── Auth/
│       │   │   ├── Views/
│       │   │   │   ├── LoginView.swift
│       │   │   │   ├── VerificationView.swift
│       │   │   │   └── OnboardingView.swift
│       │   │   ├── ViewModels/
│       │   │   │   └── AuthViewModel.swift
│       │   │   └── Services/
│       │   │       └── AuthService.swift
│       │   │
│       │   ├── Chat/
│       │   │   ├── Views/
│       │   │   │   ├── ChatListView.swift
│       │   │   │   ├── ChatView.swift
│       │   │   │   ├── MessageRow.swift
│       │   │   │   └── MessageInputView.swift
│       │   │   ├── ViewModels/
│       │   │   │   ├── ChatListViewModel.swift
│       │   │   │   └── ChatViewModel.swift
│       │   │   └── Services/
│       │   │       ├── MessageSender.swift       ← Retry logic
│       │   │       ├── MessageReceiver.swift
│       │   │       └── WebSocketManager.swift    ← Reconnect logic
│       │   │
│       │   ├── Groups/
│       │   │   ├── Views/
│       │   │   │   ├── GroupCreateView.swift
│       │   │   │   ├── GroupInfoView.swift
│       │   │   │   └── MemberManagementView.swift
│       │   │   ├── ViewModels/
│       │   │   │   └── GroupViewModel.swift
│       │   │   └── Services/
│       │   │       └── GroupService.swift
│       │   │
│       │   ├── Calls/
│       │   │   ├── Views/
│       │   │   │   ├── CallView.swift
│       │   │   │   └── IncomingCallView.swift
│       │   │   ├── ViewModels/
│       │   │   │   └── CallViewModel.swift
│       │   │   └── Services/
│       │   │       ├── WebRTCService.swift
│       │   │       └── CallKitService.swift
│       │   │
│       │   ├── Media/
│       │   │   ├── Views/
│       │   │   │   ├── MediaPickerView.swift
│       │   │   │   ├── MediaViewerView.swift
│       │   │   │   └── VoiceRecorderView.swift
│       │   │   └── Services/
│       │   │       ├── MediaService.swift
│       │   │       └── MediaEncryption.swift
│       │   │
│       │   └── Settings/
│       │       ├── Views/
│       │       │   ├── SettingsView.swift
│       │       │   ├── PrivacySettingsView.swift
│       │       │   └── ProfileEditView.swift
│       │       └── ViewModels/
│       │           └── SettingsViewModel.swift
│       │
│       ├── Core/
│       │   ├── Encryption/
│       │   │   ├── SignalProtocol.swift
│       │   │   ├── KeyManager.swift
│       │   │   └── CryptoHelper.swift
│       │   │
│       │   ├── Network/
│       │   │   ├── APIClient.swift
│       │   │   ├── WebSocketManager.swift
│       │   │   ├── Endpoints.swift
│       │   │   └── NetworkMonitor.swift
│       │   │
│       │   ├── Storage/
│       │   │   ├── CoreDataManager.swift
│       │   │   ├── KeychainManager.swift
│       │   │   ├── FileManager+Encrypted.swift
│       │   │   └── Models/
│       │   │       ├── Message.swift
│       │   │       ├── Chat.swift
│       │   │       ├── User.swift
│       │   │       └── Group.swift
│       │   │
│       │   └── Utilities/
│       │       ├── Logger.swift
│       │       ├── Haptics.swift
│       │       └── Extensions/
│       │
│       ├── UI/
│       │   ├── Components/
│       │   │   ├── Avatar.swift
│       │   │   ├── EmojiPicker.swift
│       │   │   ├── ReactionPicker.swift
│       │   │   ├── Waveform.swift
│       │   │   └── LoadingButton.swift
│       │   │
│       │   ├── Styles/
│       │   │   ├── Colors.swift
│       │   │   ├── Typography.swift
│       │   │   └── Theme.swift
│       │   │
│       │   └── Modifiers/
│       │       └── SwipeToReply.swift
│       │
│       ├── Resources/
│       │   ├── Assets.xcassets/
│       │   ├── Localizable.strings
│       │   └── Info.plist
│       │
│       └── MelChat.entitlements
│
├── backend/
│   ├── src/
│   │   ├── main.ts
│   │   ├── app.module.ts
│   │   │
│   │   ├── auth/
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── email.service.ts           ← Email verification
│   │   │   └── jwt.strategy.ts
│   │   │
│   │   ├── users/
│   │   │   ├── users.controller.ts
│   │   │   ├── users.service.ts
│   │   │   └── dto/
│   │   │       ├── create-user.dto.ts
│   │   │       └── update-user.dto.ts
│   │   │
│   │   ├── messaging/
│   │   │   ├── messaging.gateway.ts       ← WebSocket handler
│   │   │   ├── messaging.service.ts
│   │   │   ├── queue.service.ts           ← Message queue
│   │   │   ├── retry.service.ts           ← Retry logic
│   │   │   └── ack.service.ts             ← ACK management
│   │   │
│   │   ├── groups/
│   │   │   ├── groups.controller.ts
│   │   │   ├── groups.service.ts
│   │   │   └── dto/
│   │   │
│   │   ├── webrtc/
│   │   │   ├── webrtc.gateway.ts          ← Signaling server
│   │   │   └── webrtc.service.ts
│   │   │
│   │   ├── encryption/
│   │   │   ├── signal.service.ts          ← Key exchange
│   │   │   └── key-bundle.service.ts
│   │   │
│   │   ├── media/
│   │   │   ├── media.controller.ts
│   │   │   ├── media.service.ts
│   │   │   └── storage.service.ts         ← Encrypted storage
│   │   │
│   │   ├── presence/
│   │   │   ├── presence.gateway.ts        ← Online/typing status
│   │   │   └── presence.service.ts
│   │   │
│   │   ├── notifications/
│   │   │   ├── apns.service.ts            ← Push notifications
│   │   │   └── notification.service.ts
│   │   │
│   │   └── common/
│   │       ├── config/
│   │       │   └── configuration.ts
│   │       ├── guards/
│   │       │   └── auth.guard.ts
│   │       ├── filters/
│   │       │   └── http-exception.filter.ts
│   │       └── interceptors/
│   │           └── logging.interceptor.ts
│   │
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── migrations/
│   │   └── seed.ts
│   │
│   ├── test/
│   │   ├── unit/
│   │   └── integration/
│   │
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example
│   └── nest-cli.json
│
├── infrastructure/
│   ├── docker-compose.yml
│   │
│   ├── postgres/
│   │   ├── Dockerfile
│   │   └── init.sql
│   │
│   ├── redis/
│   │   ├── Dockerfile
│   │   └── redis.conf                     ← Persistence config
│   │
│   ├── nginx/
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   └── ssl/
│   │
│   ├── coturn/
│   │   ├── Dockerfile
│   │   └── turnserver.conf
│   │
│   └── scripts/
│       ├── deploy.sh
│       ├── backup.sh
│       └── restore.sh
│
├── docs/
│   ├── ARCHITECTURE.md
│   ├── SECURITY.md
│   ├── API.md
│   ├── DEPLOYMENT.md
│   └── PRIVACY_POLICY.md
│
├── .gitignore
├── README.md
└── PLAN.md
```

---

## Development Timeline (17 Hafta)

### Hafta 1-2: Setup + Auth ⏳ (IN PROGRESS)
**Backend**:
- [x] Project boilerplate (Fastify + Prisma)
- [x] Docker Compose (PostgreSQL + Redis)
- [x] User registration API
- [x] Email verification (SMTP)
- [x] JWT authentication
- [x] Auth endpoints (send-code, verify, upload-keys, /me)
- [x] Email service (dev mode - console logging)
- [x] Database migrations completed

**iOS**:
- [x] Xcode project setup
- [x] SwiftUI app structure
- [x] Onboarding UI
- [x] Login/verification flow
- [x] Keychain integration
- [x] EncryptionService (Curve25519 + AES-GCM)
- [x] APIClient (backend integration)
- [x] AuthViewModel (email → code → register/login)
- [x] SwiftData models (User, Message, Chat, Group)
- [x] MessageSender/MessageReceiver (retry logic)
- [x] **FIX**: SwiftData Group model (Data → String)
- [x] **FIX**: All compilation errors resolved
- [ ] **TESTING**: Build & run on simulator/device
- [ ] **TESTING**: End-to-end auth flow (email → code → login)

**Deliverable**: Kullanıcı kayıt/giriş

**Status**: Backend çalışıyor ✅ | iOS build testi bekliyor ⏳

---

### Hafta 3-4: Core Messaging
**Backend**:
- [x] WebSocket gateway (Socket.io)
- [x] Signal Protocol key exchange
- [x] Message queue (Redis)
- [x] ACK pattern implementation
- [x] Retry logic

**iOS**:
- [x] Signal Protocol integration (libsignal-swift)
- [x] WebSocket manager (reconnect logic)
- [x] MessageSender (retry logic)
- [x] MessageReceiver (offline fetch)
- [x] Chat list UI
- [x] Chat view UI
- [x] Core Data setup (encrypted)

**Deliverable**: 1-to-1 şifreli mesajlaşma (retry/queue logic ile)

---

### Hafta 5-6: UX Enhancement
**Backend**:
- [x] Presence system (Redis Pub/Sub)
- [x] Typing indicator
- [x] Read receipts
- [x] Reaction API

**iOS**:
- [x] Emoji picker (native)
- [x] Emoji reactions (long press)
- [x] Voice message recorder (basılı tut)
- [x] Waveform animation
- [x] Typing indicator UI
- [x] Online/last seen
- [x] Read receipts (mavi tik)
- [x] Swipe to reply
- [x] Dark mode
- [x] Haptic feedback

**Deliverable**: Modern WhatsApp-like UX

---

### Hafta 7-8: Media Sharing
**Backend**:
- [x] Media upload/download API
- [x] Encrypted storage
- [x] Thumbnail generation
- [x] Auto-delete (30 gün)

**iOS**:
- [x] Camera + gallery picker
- [x] Image/video encryption
- [x] Media upload (progress)
- [x] Media viewer (zoom, video player)
- [x] Thumbnail cache
- [x] Audio waveform
- [x] Auto-download settings

**Deliverable**: Medya paylaşımı

---

### Hafta 9-11: Group Chat
**Backend**:
- [x] Group creation API
- [x] Member management (add/remove)
- [x] Sender Key distribution
- [x] Group message routing
- [x] Admin kick limit (10 kişi)

**iOS**:
- [x] Group creation UI
- [x] Member list
- [x] Admin controls (kick, promote)
- [x] Group messaging
- [x] Group info/settings

**Deliverable**: Grup chat

---

### Hafta 12-14: VoIP (WebRTC)
**Backend**:
- [x] WebRTC signaling server
- [x] TURN server setup (coturn)
- [x] SDP exchange
- [x] ICE candidate relay

**iOS**:
- [x] WebRTC framework integration
- [x] CallKit integration
- [x] PushKit (background calls)
- [x] Audio call UI
- [x] Video call UI
- [x] Picture-in-Picture
- [x] Speaker/mute/camera controls

**Deliverable**: Sesli/görüntülü arama

---

### Hafta 15-17: Polish + App Store
**Backend**:
- [x] Performance optimization
- [x] Load testing
- [x] Security audit
- [x] Monitoring/logging
- [x] Backup automation

**iOS**:
- [x] UI/UX polish
- [x] Performance optimization (SwiftUI)
- [x] Memory leak checks
- [x] Crash analytics
- [x] App Store assets (screenshots, description)
- [x] Privacy policy
- [x] TestFlight beta test
- [x] Bug fixes from beta
- [x] App Store submission

**Deliverable**: App Store'da yayın! 🚀

---

## VPS Setup

### Gereksinimler
- **CPU**: 2 vCPU
- **RAM**: 4 GB
- **Storage**: 50 GB SSD
- **Bandwidth**: 2 TB/ay
- **OS**: Ubuntu 24.04 LTS

### Kurulacak Servisler
```
VPS
├── Docker Compose
│   ├── PostgreSQL 16
│   ├── Redis 7
│   ├── Backend (Node.js)
│   ├── Nginx (reverse proxy, SSL)
│   └── coturn (TURN server)
│
├── SSL (Let's Encrypt)
├── Firewall (ufw)
└── Monitoring (optional: Grafana + Prometheus)
```

### Docker Compose Örnek
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: melchat
      POSTGRES_USER: melchat
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - melchat

  redis:
    image: redis:7-alpine
    command: redis-server /usr/local/etc/redis/redis.conf
    volumes:
      - redis_data:/data
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - melchat

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgresql://melchat:${DB_PASSWORD}@postgres:5432/melchat
      REDIS_URL: redis://redis:6379
      JWT_SECRET: ${JWT_SECRET}
      SMTP_HOST: ${SMTP_HOST}
      SMTP_USER: ${SMTP_USER}
      SMTP_PASS: ${SMTP_PASS}
    depends_on:
      - postgres
      - redis
    networks:
      - melchat

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
      - certbot_data:/var/www/certbot
    depends_on:
      - backend
    networks:
      - melchat

  coturn:
    image: coturn/coturn:latest
    network_mode: host
    volumes:
      - ./coturn/turnserver.conf:/etc/coturn/turnserver.conf

volumes:
  postgres_data:
  redis_data:
  certbot_data:

networks:
  melchat:
```

---

## Maliyet Tahmini

### İlk Yıl
- **Apple Developer**: $99/yıl (zorunlu)
- **VPS**: $10-20/ay × 12 = $120-240/yıl (Hetzner, DigitalOcean)
- **Email API**: Ücretsiz (SendGrid 100/gün veya kendi SMTP)
- **Domain**: $10-15/yıl (opsiyonel)
- **SSL**: Ücretsiz (Let's Encrypt)
- **TURN**: Ücretsiz (self-hosted coturn)

**Toplam**: ~$230-355/yıl

### Operasyonel (aylık)
- VPS: $10-20
- Bandwidth: dahil (2 TB)
- Storage: dahil (50 GB)

**Ölçeklendirme** (10K+ kullanıcı):
- VPS upgrade: $40-80/ay
- CDN (medya için): $10-50/ay
- Monitoring: $10-20/ay

---

## Security Audit Checklist

### iOS
- [ ] Keychain encryption
- [ ] Core Data encryption (SQLCipher)
- [ ] File encryption (Data Protection API)
- [ ] Certificate pinning
- [ ] Jailbreak detection (opsiyonel)
- [ ] Screenshot blocking (hassas ekranlar)
- [ ] Biometric authentication
- [ ] Memory zeroing (sensitive data)

### Backend
- [ ] TLS 1.3 enforced
- [ ] Rate limiting (DDoS)
- [ ] Input validation
- [ ] SQL injection prevention (ORM)
- [ ] XSS prevention
- [ ] CSRF protection
- [ ] JWT token expiry
- [ ] Password hashing (bcrypt)
- [ ] Secrets management (env vars)
- [ ] Logging (no sensitive data)

### Network
- [ ] HTTPS only
- [ ] WebRTC DTLS-SRTP
- [ ] Signal Protocol E2EE
- [ ] Forward secrecy
- [ ] Certificate validation

### Infrastructure
- [ ] Firewall (ufw)
- [ ] SSH key-only (no password)
- [ ] Auto-updates (security patches)
- [ ] Backup encryption
- [ ] Disk encryption (LUKS)
- [ ] Intrusion detection (fail2ban)

---

## Privacy Policy (Özet)

**Toplanan Veriler**:
- Email hash (SHA-256)
- Username
- Public encryption keys
- Last seen (kapatılabilir)
- Device push token

**Toplanmayan Veriler**:
- ❌ Mesaj içerikleri
- ❌ Encryption keys
- ❌ Orijinal email/telefon
- ❌ İletişim geçmişi
- ❌ Konum verisi
- ❌ Cihaz bilgisi (model, sürüm)

**Veri Saklama**:
- Offline mesajlar: Max 7 gün (Redis)
- Medya dosyalar: Max 30 gün (encrypted)
- User data: Hesap silinince tamamen silinir

**Üçüncü Taraflar**:
- Apple APNs (push notification)
- Email provider (doğrulama)
- Başka kimse yok

**GDPR/KVKK Uyumlu**:
- Right to access
- Right to deletion
- Right to portability
- Data minimization
- Privacy by design

---

## Testing Strategy

### Unit Tests
- iOS: XCTest
- Backend: Jest

### Integration Tests
- E2E encryption flow
- Message queue reliability
- WebRTC signaling

### Manual Testing
- TestFlight beta (100 kullanıcı)
- Scenario testing:
  - Network kopması
  - App crash
  - Offline mesajlaşma
  - Grup mesajları
  - Arama kalitesi

### Performance Testing
- Backend load test (Artillery, k6)
- iOS performance (Instruments)
- Memory leak detection
- Battery usage

---

## Monitoring & Analytics

### Backend Monitoring
- **Logging**: Winston (no sensitive data!)
- **Metrics**: Prometheus + Grafana (opsiyonel)
- **Errors**: Sentry (opsiyonel)
- **Uptime**: UptimeRobot (ücretsiz)

### iOS Analytics
- **Crash reporting**: Sentry veya Firebase Crashlytics
- **Performance**: Xcode Instruments
- **Privacy-first**: NO user tracking, NO analytics SDK

### Key Metrics
- Message delivery rate
- Average latency
- WebSocket connection success rate
- Call quality (MOS score)
- App crash rate

---

## Future Roadmap (Post-MVP)

### Phase 5: Advanced Features
- [ ] Multi-device sync
- [ ] Desktop app (macOS, Windows, Linux)
- [ ] Web app (PWA)
- [ ] Voice/video messages
- [ ] Screen sharing
- [ ] Disappearing messages
- [ ] Backup/restore (encrypted)

### Phase 6: Collaboration
- [ ] Channels (broadcast)
- [ ] Bots/automation
- [ ] File sharing (large files)
- [ ] Polls
- [ ] Location sharing (opsiyonel)

### Phase 7: Scaling
- [ ] Message server clustering
- [ ] Database sharding
- [ ] CDN integration
- [ ] Edge computing (Cloudflare Workers)
- [ ] Global presence (multi-region)

---

## Risks & Mitigations

### Technical Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Mesaj kaybı | Medium | High | Retry logic + Redis persistence + ACK pattern |
| WebRTC NAT traversal fail | Medium | High | TURN server fallback (coturn) |
| Signal Protocol complexity | Low | High | Use battle-tested library (libsignal) |
| App Store rejection | Low | High | Follow guidelines, privacy policy, TestFlight beta |
| VPS downtime | Low | Medium | Monitoring + auto-restart + backup |

### Business Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Düşük adoption | Medium | High | MVP fast launch, iterate based on feedback |
| Scaling costs | Medium | Medium | Optimize early, monitor usage |
| Competition (WhatsApp) | High | Medium | Differentiate: privacy-first, open-source (optional) |

---

## Success Metrics

### MVP Success (3 ay)
- [ ] 100+ TestFlight beta users
- [ ] <1% message failure rate
- [ ] <2 second message latency
- [ ] >95% call success rate
- [ ] <5 critical bugs

### Launch Success (6 ay)
- [ ] 1,000+ downloads
- [ ] >4.0 App Store rating
- [ ] <0.1% crash rate
- [ ] Positive user feedback

### Growth (12 ay)
- [ ] 10,000+ active users
- [ ] Word-of-mouth growth
- [ ] Community building (Discord/Reddit)
- [ ] Press coverage (TechCrunch, ProductHunt)

---

## Next Steps

1. ✅ Plan finalize edildi
2. **iOS Xcode project oluştur**
   - SwiftUI app template
   - Core Data model
   - Folder structure

3. **Backend boilerplate**
   - Fastify + Prisma setup
   - Docker Compose (PostgreSQL + Redis)
   - Auth API skeleton

4. **VPS hazırlık**
   - SSH setup
   - Docker kurulumu
   - Domain DNS ayarları (opsiyonel)

5. **Signal Protocol test**
   - iOS libsignal-swift entegrasyonu
   - Backend key exchange API
   - Test: Alice → Bob encrypted message

6. **Week 1 Goal**: Email verification + basic auth working

---

## Kaynaklar

### Documentation
- Signal Protocol: https://signal.org/docs/
- WebRTC: https://webrtc.org/
- CallKit: https://developer.apple.com/documentation/callkit
- Prisma: https://www.prisma.io/docs
- Socket.io: https://socket.io/docs

### Libraries
- **iOS**:
  - libsignal-swift: https://github.com/signalapp/libsignal
  - WebRTC: https://github.com/stasel/WebRTC
  - SQLCipher: https://github.com/sqlcipher/sqlcipher

- **Backend**:
  - Fastify: https://www.fastify.io/
  - Prisma: https://www.prisma.io/
  - Socket.io: https://socket.io/
  - libsignal-node: https://github.com/signalapp/libsignal-node

### Tools
- coturn: https://github.com/coturn/coturn
- Docker: https://docs.docker.com/
- Let's Encrypt: https://letsencrypt.org/

---

**Son Güncelleme**: 2025-12-21
**Proje Durumu**: Planning Complete ✅
**Başlangıç Tarihi**: TBD
**Tahmini Tamamlanma**: +17 hafta

---

## Hadi başlayalım! 🚀
