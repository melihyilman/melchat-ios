# 🔍 CURRENT SERVICES AUDIT

## ✅ ACTIVE SERVICES (Keep & Use)

### Core Services:
- `SimpleEncryption.swift` ✅ - Curve25519 + AES-GCM encryption
- `KeychainHelper.swift` ✅ - Keychain storage
- `TokenManager.swift` ✅ - JWT token management
- `APIClient.swift` ✅ - REST API client
- `WebSocketManager.swift` ✅ - Real-time WebSocket
- `NetworkLogger.swift` ✅ - Network debugging
- `HapticManager.swift` ✅ - Haptic feedback
- `MessageReceiver.swift` ✅ - Message handling

### Data Models:
- `Models.swift` ✅ - User, Message, Chat, Group

### ViewModels:
- `AuthViewModel.swift` ✅ - Authentication logic
- `ChatViewModel.swift` ✅ - Individual chat logic
- `ChatListViewModel.swift` ✅ - Chat list logic

### Views:
- `ContentView.swift` ✅ - Main app view
- `AuthViews.swift` ✅ - Login/signup views
- `ChatViews.swift` ✅ - Chat UI
- `SettingsView.swift` ✅ - Settings UI

### UI Components:
- `AnimatedCharacters.swift` ✅ - Animations
- `PikachuAnimationView.swift` ✅ - Pikachu animations
- `VoiceRecorder.swift` ✅ - Voice recording

---

## ❌ DEPRECATED SERVICES (Delete if found)

### Old Encryption (SEARCH & DELETE):
```bash
# Search for these patterns:
grep -r "SignalProtocolManager" . --include="*.swift" | wc -l
grep -r "DoubleRatchetManager" . --include="*.swift" | wc -l
grep -r "EncryptionService" . --include="*.swift" | wc -l

# If found, delete those files!
```

**Files to look for and DELETE:**
- SignalProtocolManager.swift
- DoubleRatchetManager.swift
- EncryptionService.swift
- Any file with "SignalProtocol" in name
- Any file with "DoubleRatchet" in name

---

## 🔄 MIGRATION CHECKLIST

### Step 1: Find Old Encryption References
```bash
# Run in project root:
grep -r "SignalProtocol" . --include="*.swift" | grep -v "DerivedData" | grep -v "Build"
grep -r "DoubleRatchet" . --include="*.swift" | grep -v "DerivedData" | grep -v "Build"
grep -r "EncryptionService" . --include="*.swift" | grep -v "DerivedData" | grep -v "Build"

# If any results → Those files reference old encryption!
# Replace with SimpleEncryption.shared
```

### Step 2: Verify Only One Implementation
```bash
# Check encryption files:
find . -name "*Encrypt*.swift" -not -path "*/DerivedData/*" -type f

# Should ONLY show:
# ./SimpleEncryption.swift

# If more files show up → DELETE extras!
```

### Step 3: Verify Model Uniqueness
```bash
# Check Models.swift:
find . -name "Models.swift" -not -path "*/DerivedData/*" -type f

# Should show EXACTLY 1 file:
# ./Models.swift

# If 2+ files → Keep largest, delete others!
```

### Step 4: Verify Helper Uniqueness
```bash
# Check KeychainHelper:
find . -name "KeychainHelper.swift" -not -path "*/DerivedData/*" -type f

# Should show EXACTLY 1 file:
# ./KeychainHelper.swift

# Check NetworkLogger:
find . -name "NetworkLogger.swift" -not -path "*/DerivedData/*" -type f

# Should show EXACTLY 1 file:
# ./NetworkLogger.swift
```

---

## 🎯 IMMEDIATE ACTION ITEMS

### Priority 1: Delete Old Encryption (HIGH)
```bash
# Search and destroy:
find . \( -name "*SignalProtocol*.swift" -o -name "*DoubleRatchet*.swift" \) \
    -not -path "*/DerivedData/*" \
    -not -path "*/Build/*" \
    -type f

# If any found → DELETE THEM!
# They are deprecated and cause confusion
```

### Priority 2: Remove Duplicate Models (HIGH)
```bash
# Find duplicates:
find . -name "Models.swift" -not -path "*/DerivedData/*" -type f

# Keep: The one with most lines (most complete)
# Delete: Others
```

### Priority 3: Remove Duplicate Helpers (MEDIUM)
```bash
# Find KeychainHelper duplicates:
find . -name "KeychainHelper.swift" -not -path "*/DerivedData/*" -type f

# Find NetworkLogger duplicates:
find . -name "NetworkLogger.swift" -not -path "*/DerivedData/*" -type f

# Keep: One of each
# Delete: Duplicates
```

### Priority 4: Organize into Folders (LOW - After duplicates removed)
- See `PROJECT_STRUCTURE_REFACTOR.md`
- Do this AFTER cleaning duplicates
- Do this IN XCODE (drag & drop)

---

## 🚨 CRITICAL: Before Deleting Files

### Backup First!
```bash
# Create backup:
cd /path/to/MelChat
tar -czf MelChat_backup_$(date +%Y%m%d_%H%M%S).tar.gz .

# Verify backup:
ls -lh MelChat_backup_*.tar.gz
```

### Check References Before Deleting:
```bash
# Example: Before deleting SignalProtocolManager.swift
grep -r "SignalProtocolManager" . --include="*.swift" | grep -v "DerivedData"

# If results show up → Those files still reference it!
# Update those references first to use SimpleEncryption
```

---

## 📋 FINAL CHECKLIST

```
[ ] Backup project
[ ] Search for old encryption files
[ ] Delete old encryption files (if any)
[ ] Search for duplicate Models.swift
[ ] Delete duplicate Models.swift (keep 1)
[ ] Search for duplicate KeychainHelper.swift
[ ] Delete duplicate KeychainHelper.swift (keep 1)
[ ] Search for duplicate NetworkLogger.swift
[ ] Delete duplicate NetworkLogger.swift (keep 1)
[ ] Build & test (⌘B)
[ ] Run & verify (⌘R)
[ ] Commit: "chore: Remove duplicate and deprecated files"
```

---

## 🎉 SUCCESS CRITERIA

After cleanup:
```bash
# Only ONE encryption file:
find . -name "*Encrypt*.swift" -not -path "*/DerivedData/*" -type f
# Result: ./SimpleEncryption.swift (ONLY!)

# Only ONE Models.swift:
find . -name "Models.swift" -not -path "*/DerivedData/*" -type f
# Result: ./Models.swift (ONLY!)

# Only ONE KeychainHelper.swift:
find . -name "KeychainHelper.swift" -not -path "*/DerivedData/*" -type f
# Result: ./KeychainHelper.swift (ONLY!)

# Only ONE NetworkLogger.swift:
find . -name "NetworkLogger.swift" -not -path "*/DerivedData/*" -type f
# Result: ./NetworkLogger.swift (ONLY!)

# Build success:
⌘B → ✅ Build Succeeded

# App runs:
⌘R → ✅ App launches & works
```

---

**Start with backup, then Priority 1!** 🚀
