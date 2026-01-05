# 🧹 CLEAN BUILD - Cache Temizleme

## ❌ Problem
iOS bazen **eski EncryptionManager** (INVALID signature), bazen **yeni SignalProtocolManager** (VALID signature) kullanıyor.

**Sebep:** Xcode cache'inde eski kod kalmış!

---

## ✅ Çözüm: Tam Clean Build

### 1️⃣ Xcode Clean Build
```bash
# Xcode menüsünden:
Product → Clean Build Folder (⌘⇧K)

# Veya terminal:
cd /path/to/MelChat
rm -rf ~/Library/Developer/Xcode/DerivedData/MelChat-*
```

### 2️⃣ Simulator Reset
```bash
# Simulator menüsünden:
Device → Erase All Content and Settings

# Veya terminal:
xcrun simctl erase all
```

### 3️⃣ Build & Run
```bash
# Xcode'da:
⌘B (Build)
⌘R (Run)
```

### 4️⃣ Yeni Hesap Oluştur
```
- Yeni email ile register ol
- Keys generate edilecek
- Signature artık ✅ VALID olmalı
- Backend 200 OK dönmeli
```

---

## 🔍 Verification

### Başarılı Loglar (Olması Gereken)
```
[Encryption] 🔑 Generating Signal Protocol keys...
[Encryption] ✅ Generated all keys successfully
[Encryption] ✅ Identity Signing Key (Ed25519): Zg/BY1...
[Encryption] ✅ Identity Key Agreement (Curve25519): qnw1PL...  ← Backend'e bu gidecek
[Network] 📤 POST /api/keys/upload
[Network] 📥 RESPONSE 200 ✅
```

### Mesaj Gönderme
```
[Encryption] 🔐 Encrypting message with Signal Protocol...
[Encryption] ✅ Session established
[Encryption] ✅ Message encrypted
[Chat] ✅ Message sent (encrypted)
[Chat] 💾 Message saved to local DB  ← Artık çalışmalı
```

---

## 📝 Checklist

- [ ] ⌘⇧K (Clean Build Folder)
- [ ] DerivedData silindi
- [ ] Simulator reset edildi
- [ ] App rebuild edildi
- [ ] Yeni hesap oluşturuldu
- [ ] Key upload 200 OK döndü
- [ ] Mesaj gönderildi
- [ ] Mesaj local DB'ye kaydedildi

---

## 🎯 Beklenen Sonuç

**BEFORE (Cache sorunu):**
```
❌ Bazen EncryptionManager kullanıyor
❌ Invalid signature
❌ Backend 500 hatası
❌ Karışık davranış
```

**AFTER (Clean build):**
```
✅ Her zaman SignalProtocolManager kullanıyor
✅ Valid signature
✅ Backend 200 OK
✅ Tutarlı davranış
```

---

## 🚀 Test Sonrası

Eğer hala sorun varsa:

### A. Xcode Project Clean
```bash
# Tamamen kapla
⌘Q (Quit Xcode)

# Workspace data sil
rm -rf ~/Library/Developer/Xcode/DerivedData/

# Xcode'u tekrar aç
open MelChat.xcodeproj
```

### B. SPM Packages Reset (Eğer CryptoKit kullanıyorsan)
```bash
File → Packages → Reset Package Caches
File → Packages → Update to Latest Package Versions
```

### C. Build Settings Kontrol
```
Xcode → Target: MelChat → Build Settings
→ Search: "Debug Information Format"
→ Ensure: DWARF with dSYM File
```

---

## 📊 Cache Dosyalarının Konumu

### Xcode DerivedData
```bash
~/Library/Developer/Xcode/DerivedData/MelChat-*/
```

### Simulator Data
```bash
~/Library/Developer/CoreSimulator/Devices/
```

### Module Cache
```bash
~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/
```

**Hepsini sil!**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/
rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/
```

---

## ✅ Final Test

1. **Clean + Reset yap**
2. **Yeni hesap oluştur**
3. **Mesaj gönder**
4. **Logları kontrol et:**

```
✅ Generated all keys successfully
✅ Keys uploaded (200 OK)
✅ Message encrypted with Signal Protocol
✅ Message sent
✅ Message saved to local DB
✅ Extracted userId from token: ...
✅ WebSocket connected
```

**Artık %100 SignalProtocolManager kullanmalı!** 🎉
