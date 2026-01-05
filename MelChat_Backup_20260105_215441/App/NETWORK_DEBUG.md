# ✅ YAPILAN DEĞİŞİKLİKLER - Network Logging & Connection Fix

## 🎯 Yapılanlar

### 1️⃣ Network Logger Eklendi
**Yeni Dosya:** `NetworkLogger.swift`

Özellikler:
- ✅ Tüm HTTP request/response'ları logluyor
- ✅ WebSocket bağlantı durumu
- ✅ JSON pretty print
- ✅ Arama yapabilme
- ✅ Detaylı log görüntüleme
- ✅ Statistics (total, requests, responses)

### 2️⃣ Shake to Show Debug Menu
**Güncellenmiş:** `ContentView.swift`

Özellik:
- 📱 **Telefonu salla** → Network logger açılır!
- Simulator'de: `Device → Shake` veya `Ctrl + Cmd + Z`

Eklenen kod:
```swift
.onShake {
    showDebugMenu = true
}
.sheet(isPresented: $showDebugMenu) {
    NetworkLoggerView()
}
```

### 3️⃣ Server Connection Fix
**Güncellenmiş:** `APIClient.swift`

Problem: `localhost` sadece simulator'de çalışır, gerçek cihazda çalışmaz.

Çözüm:
```swift
#if targetEnvironment(simulator)
private let baseURL = "http://localhost:3000/api"
#else
private let baseURL = "http://192.168.1.100:3000/api" // Mac'in IP'si
#endif
```

### 4️⃣ WebSocket Connection Fix
**Güncellenmiş:** `WebSocketManager.swift`

Aynı fix WebSocket için:
```swift
#if targetEnvironment(simulator)
let wsURL = "ws://localhost:3000/ws/messaging"
#else
let wsURL = "ws://192.168.1.100:3000/ws/messaging"
#endif
```

### 5️⃣ Request/Response Logging
**Güncellenmiş:** `APIClient.swift`

Her request ve response loglanıyor:
```swift
NetworkLogger.shared.logRequest(request, body: body)
NetworkLogger.shared.logResponse(httpResponse, data: data)
```

---

## 🚀 KULLANIM

### Backend'i Hazırla
1. Backend'de `server.js` şöyle olmalı:
```javascript
app.listen(3000, '0.0.0.0', () => {
  console.log('Server running on port 3000');
});
```

2. Backend'i başlat:
```bash
npm run dev
```

### Mac'in IP Adresini Öğren
```bash
ipconfig getifaddr en0
```

Örnek output: `192.168.1.100`

### IP'yi App'e Gir

**1. APIClient.swift** (satır ~8):
```swift
private let baseURL = "http://192.168.1.100:3000/api"  // ← Kendi IP'ni yaz
```

**2. WebSocketManager.swift** (satır ~24):
```swift
let wsURL = "ws://192.168.1.100:3000/ws/messaging"  // ← Kendi IP'ni yaz
```

### Build & Run
```bash
⌘ + B   # Build
⌘ + R   # Run
```

---

## 🔍 DEBUG NASIL YAPILIR

### 1. Network Logger'ı Aç
- **Gerçek Cihaz:** Telefonu salla
- **Simulator:** `Device → Shake` veya `Ctrl + Cmd + Z`

### 2. Ne Görürsün?
- 📊 **Statistics**: Toplam, request, response sayıları
- 📋 **Log List**: Tüm network aktiviteleri
- 🔍 **Search**: Log içinde ara
- 📄 **Details**: Bir log'a tıkla → Detaylı görüntüle

### 3. Ne Ara?
- Request gönderildi mi? → `📤 REQUEST` loglarına bak
- Response geldi mi? → `📥 RESPONSE` loglarına bak
- Status code ne? → 200 = başarılı, 400+ = hata
- WebSocket bağlandı mı? → `✅ WebSocket connected` ara

### 4. Örnek Başarılı Log
```
🌐 API Client initialized - Base URL: http://192.168.1.100:3000/api

📤 REQUEST
URL: http://192.168.1.100:3000/api/auth/send-code
Method: POST
Body: {"email":"test@example.com"}

📥 RESPONSE
Status: 200
Body: {
  "success": true,
  "message": "Verification code sent"
}

🔌 Connecting to WebSocket: ws://192.168.1.100:3000/ws/messaging
✅ WebSocket connected for user: 550e8400-e29b-41d4-a716-446655440000
```

---

## 🐛 SORUN GİDERME

### "Could not connect to the server"
1. Backend çalışıyor mu? → Terminal'de kontrol et
2. Doğru IP'yi yazdın mı? → `APIClient.swift` ve `WebSocketManager.swift`
3. Aynı Wi-Fi'de misiniz? → Mac ve telefon

### Network Logger'da "❌ Invalid URL"
- IP adresi yanlış yazılmış
- Backend çalışmıyor

### Network Logger'da "❌ Invalid response"
- Backend çöktü
- Backend yanlış response döndürüyor

### WebSocket "Connection failed"
- Backend WebSocket server'ı çalışmıyor
- `ws://` yerine `http://` yazmışsın

---

## 📁 OLUŞTURULAN/GÜNCELLENEN DOSYALAR

- ✅ `NetworkLogger.swift` (YENİ) - Network logging sistemi
- ✅ `ContentView.swift` - Shake gesture eklendi
- ✅ `APIClient.swift` - IP detection + logging
- ✅ `WebSocketManager.swift` - IP detection + logging
- 📄 `SERVER_CONNECTION_GUIDE.md` - Detaylı rehber
- 📄 `NETWORK_DEBUG.md` (bu dosya) - Özet

---

## ✅ CHECKLIST

Backend:
- [ ] Backend `npm run dev` ile çalışıyor
- [ ] Backend `0.0.0.0:3000` dinliyor
- [ ] Mac ve cihaz aynı Wi-Fi'de

App:
- [ ] Mac'in IP'sini öğrendim (`ipconfig getifaddr en0`)
- [ ] `APIClient.swift`'te IP'yi güncelledim
- [ ] `WebSocketManager.swift`'te IP'yi güncelledim
- [ ] Build aldım (`⌘ + B`)

Test:
- [ ] Safari'den `http://YOUR_IP:3000` açılıyor
- [ ] App'i açtım
- [ ] Telefonu salladım → Network logger açıldı
- [ ] Email gönderdim → Logs'da request göründü

---

## 🎉 BAŞARILI!

Network logger'da request/response görünüyorsa başarılı! 🚀

Artık her network aktivitesini görebilir ve debug yapabilirsin.

**İyi çalışmalar!** 💪
