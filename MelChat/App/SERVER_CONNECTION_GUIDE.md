# SERVER BAĞLANTI REHBERİ

## 🎯 Problem
App, gerçek cihazdan `localhost:3000`'e bağlanamıyor çünkü localhost sadece simulator'de çalışıyor.

## ✅ Çözüm

### 1️⃣ Mac'in IP Adresini Öğren

**Yöntem 1: Terminal**
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

**Yöntem 2: System Settings**
- System Settings → Network → Wi-Fi → Details
- IP adresini kopyala (örnek: `192.168.1.100`)

**Yöntem 3: Hızlı Komut**
```bash
ipconfig getifaddr en0
```

### 2️⃣ Backend'i Tüm Network Interface'lerde Dinlet

Backend'in sadece `localhost` yerine tüm IP'lerde dinlemesi lazım.

**server.js'de şöyle olmalı:**
```javascript
const PORT = 3000;

// ❌ YANLIŞ - Sadece localhost:
// app.listen(PORT, 'localhost', () => {...})

// ✅ DOĞRU - Tüm interfaces:
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Access from same network: http://YOUR_IP:${PORT}`);
});
```

**Ya da hiç IP belirtme:**
```javascript
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 3️⃣ Firewall'u Aç (Gerekirse)

Mac firewall kapalıysa problem olmaz. Açıksa:
- System Settings → Network → Firewall
- Node.js'e izin ver

### 4️⃣ IP Adresini App'e Gir

**APIClient.swift** ve **WebSocketManager.swift** dosyalarında:

```swift
// TODO: Mac'in gerçek IP'sini buraya yaz
private let baseURL = "http://192.168.1.100:3000/api"  // ← Kendi IP'ini yaz
```

```swift
// TODO: Mac'in gerçek IP'sini buraya yaz
let wsURL = "ws://192.168.1.100:3000/ws/messaging"  // ← Kendi IP'ini yaz
```

### 5️⃣ Aynı Wi-Fi'de Ol

- Mac ve iPhone/iPad **aynı Wi-Fi ağında** olmalı
- Hotspot veya farklı network çalışmaz

---

## 🔍 Debug - Telefonu Salla!

App çalışırken **telefonu salla** → Network logs açılır!

### Network Logger Özellikleri:
- ✅ Tüm HTTP istekleri
- ✅ Request headers & body
- ✅ Response status & body
- ✅ WebSocket bağlantı durumu
- ✅ JSON pretty print
- ✅ Arama yapabilirsin
- ✅ Detaylı log görüntüleme

### Kullanım:
1. **Telefonu salla** (Simulator'de: Device → Shake)
2. Network logger açılır
3. Request/response'ları gör
4. Bir log'a tıkla → Detaylı görüntüle
5. "Clear" ile temizle

---

## 🧪 Test Et

### 1. Backend Çalışıyor mu?
```bash
curl http://localhost:3000/api/health
# ya da
curl http://YOUR_IP:3000/api/health
```

### 2. Network'ten Erişilebiliyor mu?
iPhone'dan Safari'ye gir:
```
http://YOUR_IP:3000
```

Sayfa açılırsa ✅ backend erişilebilir

### 3. App'den Test
1. App'i aç
2. Email gir
3. Telefonu salla
4. Network logs'da şunları ara:
   - `📤 REQUEST` - İstek gönderildi mi?
   - `📥 RESPONSE` - Cevap geldi mi?
   - Status code nedir? (200 = başarılı)

---

## 🐛 Sık Sorunlar

### "Could not connect to the server"
- Backend çalışıyor mu? → `npm run dev` veya `node server.js`
- Doğru IP'yi yazdın mı?
- Aynı Wi-Fi'de misiniz?

### "Connection refused"
- Backend `0.0.0.0` veya hiç IP belirtmeden dinliyor olmalı
- Firewall kapalı veya Node.js'e izin verilmiş olmalı

### "Request timeout"
- Network çok yavaş
- Backend yanıt vermiyor
- IP adresi yanlış

### WebSocket "Connection failed"
- Backend WebSocket sunucusu çalışıyor mu?
- Doğru URL'i kullanıyor musun? (`ws://` not `http://`)
- Port doğru mu? (Genellikle aynı port: 3000)

---

## 📝 Hızlı Checklist

Backend hazır mı?
- [ ] Backend `npm run dev` ile çalışıyor
- [ ] Backend `0.0.0.0:3000` veya tüm interfaces'de dinliyor
- [ ] Mac ve cihaz aynı Wi-Fi'de

App hazır mı?
- [ ] APIClient.swift'te IP güncel
- [ ] WebSocketManager.swift'te IP güncel
- [ ] App build alındı ve kuruldu

Test et:
- [ ] Safari'den `http://YOUR_IP:3000` açılıyor
- [ ] App'i aç → Telefonu salla → Logs görünüyor
- [ ] Email gönder → Network logs'da request var mı?

---

## 🎉 Başarıyla Bağlandıysa

Network logger'da şunları göreceksin:
```
🌐 API Client initialized - Base URL: http://192.168.1.100:3000/api
📤 REQUEST
URL: http://192.168.1.100:3000/api/auth/send-code
Method: POST
Body: {"email":"test@example.com"}

📥 RESPONSE
URL: http://192.168.1.100:3000/api/auth/send-code
Status: 200
Body: {
  "success": true,
  "message": "Verification code sent"
}

🔌 Connecting to WebSocket: ws://192.168.1.100:3000/ws/messaging
✅ WebSocket connected for user: 550e8400-e29b-41d4-a716-446655440000
```

---

**İyi çalışmalar!** 🚀
