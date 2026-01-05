# 🔍 DUPLICATE & DEPRECATED FILES - FINAL CHECK

## 🎯 Amaç
Projede **SADECE BİR** implementasyon olmalı. Duplicate'leri ve deprecated dosyaları bul ve sil.

---

## ✅ CURRENT SINGLE SOURCE OF TRUTH

### Encryption (ONLY ONE!)
```
✅ SimpleEncryption.swift
   - Location: Core/Encryption/
   - Class: SimpleEncryption
   - Methods: encrypt(), decrypt(), generateKeys()
   - Status: ACTIVE ✅
```

### Keychain (ONLY ONE!)
```
✅ KeychainHelper-Storage.swift (or KeychainHelper.swift)
   - Location: Root (will be moved later)
   - Class: KeychainHelper
   - Methods: save(), load(), delete()
   - Status: ACTIVE ✅
```

### Token Management (ONLY ONE!)
```
✅ TokenManager.swift
   - Location: Core/Network/
   - Class: TokenManager
   - Methods: saveTokens(), getAccessToken(), refreshToken()
   - Status: ACTIVE ✅
```

### Models (ONLY ONE!)
```
✅ Models.swift
   - Location: Core/Storage/Models/
   - Contains: User, Message, Chat, Group
   - Status: ACTIVE ✅
```

### Network Logger (ONLY ONE!)
```
✅ NetworkLogger.swift
   - Location: Core/Networking/ (moved from App/)
   - Class: NetworkLogger
   - Status: ACTIVE ✅
```

---

## ❌ DEPRECATED FILES - MUST DELETE IF FOUND

### Old Encryption (Signal Protocol - DEPRECATED!)
```bash
# Search for these files:
find . -name "*SignalProtocol*.swift" -not -path "*/DerivedData/*" -type f
find . -name "*DoubleRatchet*.swift" -not -path "*/DerivedData/*" -type f
find . -name "EncryptionService*.swift" -not -path "*/DerivedData/*" -type f
find . -name "EncryptionManager*.swift" -not -path "*/DerivedData/*" -type f
find . -name "*libsignal*.swift" -not -path "*/DerivedData/*" -type f

# Expected result: NOTHING! (all deleted)
```

**Files to DELETE if found:**
- ❌ SignalProtocolManager.swift
- ❌ DoubleRatchetManager.swift
- ❌ EncryptionService.swift
- ❌ EncryptionManager.swift
- ❌ Any file with "SignalProtocol" in name
- ❌ Any file with "DoubleRatchet" in name
- ❌ Any file with "libsignal" in name

---

## 🔍 DUPLICATE CHECK COMMANDS

### 1. Check for Duplicate Encryption
```bash
cd /Users/melih/dev/melchat/MelChat/MelChat

# Find all encryption-related files
find . -name "*Encrypt*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f

# Expected output (ONLY ONE!):
# ./Core/Encryption/SimpleEncryption.swift
```

### 2. Check for Duplicate KeychainHelper
```bash
# Find all KeychainHelper files
find . -name "*Keychain*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f

# Expected output (ONLY ONE!):
# ./KeychainHelper-Storage.swift
# OR
# ./Core/Security/KeychainHelper.swift
```

### 3. Check for Duplicate Models
```bash
# Find all Models.swift files
find . -name "Models.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f

# Expected output (ONLY ONE!):
# ./Core/Storage/Models/Models.swift
```

### 4. Check for Duplicate TokenManager
```bash
# Find all TokenManager files
find . -name "*Token*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f

# Expected output (should include ONLY):
# ./Core/Network/TokenManager.swift
```

### 5. Check for Duplicate NetworkLogger
```bash
# Find all NetworkLogger files
find . -name "*NetworkLogger*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f

# Expected output (ONLY ONE!):
# ./Core/Networking/NetworkLogger.swift
```

### 6. Search for Old Encryption References in Code
```bash
# Check if any file still references old encryption
grep -r "SignalProtocol" . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" | grep -v ".md"
grep -r "DoubleRatchet" . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" | grep -v ".md"
grep -r "EncryptionService" . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" | grep -v ".md"

# Expected output: NOTHING!
# If found, those files still reference old encryption → UPDATE THEM!
```

---

## 🚨 CRITICAL: Function Definitions

### ✅ Encryption Functions (ONLY in SimpleEncryption.swift)
```swift
// ONLY defined in: Core/Encryption/SimpleEncryption.swift

class SimpleEncryption {
    static let shared = SimpleEncryption()
    
    func generateKeys() -> String { }
    func encrypt(message: String, recipientPublicKey: String) throws -> String { }
    func decrypt(ciphertext: String, senderPublicKey: String) throws -> String { }
    func hasKeys() -> Bool { }
    func loadKeys() { }
}
```

**NEVER define these functions elsewhere!**

### ✅ Keychain Functions (ONLY in KeychainHelper)
```swift
// ONLY defined in: KeychainHelper-Storage.swift (or KeychainHelper.swift)

class KeychainHelper {
    func save(_ data: Data, forKey key: String) throws { }
    func load(forKey key: String) throws -> Data { }
    func delete(forKey key: String) throws { }
}
```

**NEVER define these functions elsewhere!**

### ✅ Token Functions (ONLY in TokenManager)
```swift
// ONLY defined in: Core/Network/TokenManager.swift

class TokenManager {
    static let shared = TokenManager()
    
    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) throws { }
    func getAccessToken() async throws -> String { }
    func getRefreshToken() throws -> String { }
    func clearTokens() { }
}
```

**NEVER define these functions elsewhere!**

---

## 🧹 CLEANUP SCRIPT

Run this to find and list all potential duplicates:

```bash
#!/bin/bash

cd /Users/melih/dev/melchat/MelChat/MelChat

echo "🔍 Checking for duplicates and deprecated files..."
echo ""

# 1. Encryption files
echo "📦 Encryption files:"
find . -name "*Encrypt*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f
echo ""

# 2. Keychain files
echo "🔑 Keychain files:"
find . -name "*Keychain*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f
echo ""

# 3. Models files
echo "📋 Models files:"
find . -name "Models.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f
echo ""

# 4. Token files
echo "🎫 Token files:"
find . -name "*Token*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f
echo ""

# 5. NetworkLogger files
echo "📡 NetworkLogger files:"
find . -name "*NetworkLogger*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f
echo ""

# 6. Old encryption (should be EMPTY!)
echo "❌ Deprecated encryption files (should be EMPTY!):"
find . \( -name "*SignalProtocol*.swift" -o -name "*DoubleRatchet*.swift" -o -name "EncryptionService*.swift" \) -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f
echo ""

# 7. Code references to old encryption
echo "🔍 Code references to old encryption (should be EMPTY!):"
grep -r "SignalProtocolManager" . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" 2>/dev/null | grep -v ".md" || echo "(none found ✅)"
grep -r "DoubleRatchetManager" . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" 2>/dev/null | grep -v ".md" || echo "(none found ✅)"
grep -r "EncryptionService" . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" 2>/dev/null | grep -v ".md" || echo "(none found ✅)"
echo ""

echo "✅ Check complete!"
```

Save as: `check_duplicates.sh`

```bash
chmod +x check_duplicates.sh
./check_duplicates.sh
```

---

## 📊 EXPECTED RESULTS

### ✅ GOOD (No duplicates, no deprecated):
```
📦 Encryption files:
./Core/Encryption/SimpleEncryption.swift

🔑 Keychain files:
./KeychainHelper-Storage.swift

📋 Models files:
./Core/Storage/Models/Models.swift

🎫 Token files:
./Core/Network/TokenManager.swift

📡 NetworkLogger files:
./Core/Networking/NetworkLogger.swift

❌ Deprecated encryption files (should be EMPTY!):
(nothing found ✅)

🔍 Code references to old encryption (should be EMPTY!):
(none found ✅)
```

### ❌ BAD (Duplicates or deprecated found):
```
📦 Encryption files:
./Core/Encryption/SimpleEncryption.swift
./Services/EncryptionService.swift          ← DELETE THIS!
./Managers/EncryptionManager.swift          ← DELETE THIS!

❌ Deprecated encryption files:
./SignalProtocolManager.swift               ← DELETE THIS!
./DoubleRatchetManager.swift                ← DELETE THIS!

🔍 Code references to old encryption:
./ViewModels/ChatViewModel.swift:142: SignalProtocolManager.shared.encrypt(...)
                                      ↑ REPLACE WITH SimpleEncryption.shared!
```

---

## 🚀 NEXT STEPS

1. **Run check_duplicates.sh**
2. **If duplicates found** → DELETE them immediately
3. **If code references old encryption** → UPDATE to SimpleEncryption.shared
4. **Run check again** → Should be clean ✅
5. **Build & test** → Cmd+B, Cmd+R

---

## ✅ FINAL CHECKLIST

```
[ ] Only ONE SimpleEncryption.swift
[ ] Only ONE KeychainHelper
[ ] Only ONE Models.swift
[ ] Only ONE TokenManager.swift
[ ] Only ONE NetworkLogger.swift
[ ] ZERO old encryption files (SignalProtocol, DoubleRatchet, etc.)
[ ] ZERO code references to old encryption
[ ] Build succeeds (Cmd+B)
[ ] App runs (Cmd+R)
```

---

**Status:** Ready to check
**Last Updated:** 2026-01-05
