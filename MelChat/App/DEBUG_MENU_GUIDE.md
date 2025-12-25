# 🔍 MelChat Debug Menu - Kullanım Kılavuzu

## ✅ Eklenen Özellikler

### 1. Network Logger
- ✅ Tüm HTTP requests/responses loglama
- ✅ WebSocket bağlantı logları
- ✅ Status code gösterimi
- ✅ Request/Response body'leri
- ✅ JSON pretty printing
- ✅ Arama fonksiyonu

### 2. Shake Gesture
- ✅ Telefonu salla → Debug menü açılır
- ✅ Simulator'da: **Device → Shake** (⌃⌘Z)

### 3. Manuel Erişim
- ✅ Settings → Developer → Network Logs butonu

---

## 🚀 Nasıl Kullanılır?

### Yöntem 1: Telefonu Salla 📱
```
1. Uygulamayı çalıştır
2. Telefonu salla (Simulator: Device → Shake veya ⌃⌘Z)
3. Network Logger ekranı açılır
```

### Yöntem 2: Manuel Buton 🔘
```
1. Settings tab'e git
2. Developer bölümünde "Network Logs" butonuna tıkla
3. Network Logger ekranı açılır
```

---

## 📊 Network Logger Özellikleri

### Ana Ekran
```
┌─────────────────────────────┐
│   Network Logs         [Clear]│
├─────────────────────────────┤
│  Total: 12  Requests: 6      │
│  Responses: 6                │
├─────────────────────────────┤
│ 🔍 Search logs...            │
├─────────────────────────────┤
│ 📤 14:23:45  POST /auth      │
│    localhost:3000/api/...   │
│    {...}                    │
│                             │
│ 📥 14:23:46  [200]           │
│    localhost:3000/api/...   │
│    {"success": true}        │
└─────────────────────────────┘
```

### Log Detayları
Her log'a tıklayınca:
- Tam URL
- Request/Response headers
- Body içeriği (JSON formatted)
- Status code
- Timestamp
- Kopyalama özelliği (text selection)

---

## 🔧 Server Bağlantısını Kontrol Etme

### 1. Backend çalışıyor mu?
Terminal'de:
```bash
cd backend
npm run dev
```

Çıktı:
```
✅ Server running on port 3000
✅ WebSocket server ready
```

### 2. App'te kontrol et

#### LoginView'da email gönderince:
```
Debug Menu'de göreceksin:

📤 REQUEST
URL: http://localhost:3000/api/auth/send-code
Method: POST
Body: {"email":"test@test.com"}

📥 RESPONSE
Status: 200
Body: {"success": true, "message": "Code sent"}
```

#### Hata varsa:
```
❌ Connection failed
- Server kapalı
- Port 3000 meşgul
- Network hatası
```

---

## 🐛 Troubleshooting

### Server'a Bağlanamıyorum

**Simulator için:**
```swift
// APIClient.swift
#if targetEnvironment(simulator)
private let baseURL = "http://localhost:3000/api"  // ✅ Bu çalışır
#endif
```

**Gerçek iPhone için:**
```swift
#else
private let baseURL = "http://192.168.1.100:3000/api"  // ❌ Mac IP'ni yaz
#endif
```

Mac IP'ni bul:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### WebSocket Bağlanmıyor

Debug menu'de ara: "WebSocket"
```
🔌 Connecting to WebSocket: ws://localhost:3000/ws/messaging
✅ WebSocket connected
```

Görmüyorsan:
1. Backend çalışıyor mu?
2. Port doğru mu?
3. IP adresi doğru mu? (gerçek cihaz için)

### Request Gözükmüyor

APIClient.swift'te kontrol et:
```swift
// Her request'ten önce
NetworkLogger.shared.logRequest(request, body: body)

// Her response'dan sonra
NetworkLogger.shared.logResponse(httpResponse, data: data)
```

---

## 📱 Simulator Kısayolları

| Aksiyon | Kısayol |
|---------|---------|
| Shake Gesture | `⌃⌘Z` |
| Rotate Left | `⌘←` |
| Rotate Right | `⌘→` |
| Home | `⇧⌘H` |
| Lock | `⌘L` |

---

## 🎯 Test Senaryosu

### 1. Email Gönderme Testi
```
1. App aç
2. Email gir: test@example.com
3. "Send Code" bas
4. Telefonu salla (⌃⌘Z)
5. Network Logs'ta gör:
   - 📤 POST /auth/send-code
   - 📥 200 response
```

### 2. Verification Testi
```
1. Code: 123456
2. "Verify" bas
3. Debug menu'de gör:
   - POST /auth/verify
   - Response: user ID + token
   - POST /auth/upload-keys
```

### 3. WebSocket Testi
```
1. Login ol
2. Debug menu'de ara: "WebSocket"
3. Göreceksin:
   - 🔌 Connecting to WebSocket
   - ✅ WebSocket connected
   - 🔵 WebSocket received message
```

---

## 🔥 Pro Tips

### 1. Hızlı Debugging
```swift
// LoginView'da debug butonu ekle (geçici):
Button("🐛") {
    showDebugMenu = true
}
```

### 2. Console ile Birlikte Kullan
```
Debug menu + Xcode console = 💪
- Debug menu: Geçmiş requests
- Console: Anlık loglar
```

### 3. Request Body Kopyalama
```
1. Log'a tıkla
2. Body'yi seç
3. Kopyala
4. Postman'de test et
```

### 4. Search Özelliği
```
- "error" ara → Tüm hataları bul
- "200" ara → Başarılı requests
- "auth" ara → Auth endpoint'leri
```

---

## ✅ Özet

### Eklenenler:
1. ✅ NetworkLogger sistemi
2. ✅ Shake gesture detection
3. ✅ Network logs UI
4. ✅ Search & filter
5. ✅ Settings menu butonu

### Kullanım:
1. 📱 Telefonu salla (⌃⌘Z)
2. 🔘 Settings → Network Logs
3. 🔍 Tüm network trafiğini gör
4. 🐛 Debug et!

---

**Şimdi build al ve test et!** 🚀

```bash
⌘+Shift+K  # Clean
⌘+B        # Build
⌘+R        # Run
⌃⌘Z        # Shake!
```
