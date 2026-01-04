# 🔑 Two Identity Keys - Backend Fix

## ❌ Previous Issue
Backend bekliyor:
- ✅ `identitySigningKey` (Ed25519) → Signature verification
- ✅ `identityKey` (Curve25519) → Key agreement/encryption

iOS sadece bir tane gönderiyordu ❌

---

## ✅ Solution

### Both Keys Now Sent to Backend

#### 1. PublicKeyBundle Updated
```swift
struct PublicKeyBundle: Codable {
    let identitySigningKey: String  // ✅ Ed25519 (for signature verification)
    let identityKey: String          // ✅ Curve25519 (for key agreement)
    let signedPrekey: String
    let signedPrekeySignature: String
    let oneTimePrekeys: [OneTimePrekey]
}
```

#### 2. generateKeys() Returns Both
```swift
return PublicKeyBundle(
    identitySigningKey: identitySigningKey.publicKey.rawRepresentation.base64EncodedString(),  // ✅ Ed25519
    identityKey: identityKey.publicKey.rawRepresentation.base64EncodedString(),                // ✅ Curve25519
    signedPrekey: signedPrekey.publicKey.rawRepresentation.base64EncodedString(),
    signedPrekeySignature: signature.base64EncodedString(),
    oneTimePrekeys: oneTimePrekeyPublics
)
```

#### 3. API Request Updated
```swift
struct UploadSignalKeysRequest: Codable {
    let identitySigningKey: String  // ✅ Ed25519
    let identityKey: String          // ✅ Curve25519
    let signedPrekey: String
    let signedPrekeySignature: String
    let oneTimePrekeys: [OneTimePrekeyData]
}
```

#### 4. uploadSignalKeys() Sends Both
```swift
let body = UploadSignalKeysRequest(
    identitySigningKey: bundle.identitySigningKey,  // ✅ Ed25519
    identityKey: bundle.identityKey,                // ✅ Curve25519
    signedPrekey: bundle.signedPrekey,
    signedPrekeySignature: bundle.signedPrekeySignature,
    oneTimePrekeys: prekeyData
)
```

---

## 📊 Key Types Explained

### Identity Signing Key (Ed25519)
- **Algorithm:** Ed25519 (Edwards-curve Digital Signature Algorithm)
- **Purpose:** Sign prekeys, verify signatures
- **Usage:** Backend verifies signature with this key
- **Size:** 32 bytes
- **Field Name:** `identitySigningKey`

### Identity Key Agreement (Curve25519)
- **Algorithm:** Curve25519 ECDH (Elliptic Curve Diffie-Hellman)
- **Purpose:** Key agreement, establish shared secrets
- **Usage:** Used in X3DH protocol for session establishment
- **Size:** 32 bytes
- **Field Name:** `identityKey`

---

## 🔄 Backend JSON Format

### Before ❌
```json
{
  "identityKey": "qnw1PLydNQQshHHZUUcLV3jEXmKblbX83Tjz1TtqxS0=",  // Only Curve25519
  "signedPrekey": "...",
  "signedPrekeySignature": "...",
  "oneTimePrekeys": [...]
}
```

### After ✅
```json
{
  "identitySigningKey": "Zg/BY1glTkJhH94PxOKmtbjjjvQNC173rkVqSz58cLA=",  // ✅ Ed25519
  "identityKey": "qnw1PLydNQQshHHZUUcLV3jEXmKblbX83Tjz1TtqxS0=",      // ✅ Curve25519
  "signedPrekey": "...",
  "signedPrekeySignature": "...",
  "oneTimePrekeys": [...]
}
```

---

## 🎯 Backend Benefits

### With Both Keys, Backend Can:

1. **Verify Signatures** (Ed25519)
   ```
   signedPrekey + signedPrekeySignature + identitySigningKey
   → Backend can verify signature is valid ✅
   ```

2. **Facilitate Key Agreement** (Curve25519)
   ```
   identityKey (Curve25519) → Used in X3DH protocol
   → Other users can establish encrypted sessions ✅
   ```

3. **Full Signal Protocol Support**
   ```
   Both keys together → Complete Signal Protocol implementation ✅
   ```

---

## 🧪 Testing

### 1. Clean Build
```bash
⌘⇧K
rm -rf ~/Library/Developer/Xcode/DerivedData/MelChat-*
xcrun simctl erase all
```

### 2. Run & Register
```bash
⌘R
# Register new account
```

### 3. Expected Logs
```
[Encryption] 🔑 Generating Signal Protocol keys...
[Encryption] ✅ Identity Signing Key (Ed25519): Zg/BY1gl...
[Encryption] ✅ Identity Key Agreement (Curve25519): qnw1PLyd...
[Network] 📤 POST /api/keys/upload
Body: {
  "identitySigningKey": "Zg/BY1gl...",  ✅
  "identityKey": "qnw1PLyd...",          ✅
  "signedPrekey": "...",
  "signedPrekeySignature": "...",
  "oneTimePrekeys": [...]
}
[Network] 📥 RESPONSE 200 ✅
[Encryption] ✅ Signal Protocol keys uploaded
```

### 4. Backend Should Accept
```
✅ 200 OK
✅ Signature verification passes
✅ Keys stored in database
```

---

## 📝 Files Changed

### 1. SignalProtocolManager.swift
```diff
  struct PublicKeyBundle: Codable {
+     let identitySigningKey: String  // Ed25519
      let identityKey: String          // Curve25519
      let signedPrekey: String
      let signedPrekeySignature: String
      let oneTimePrekeys: [OneTimePrekey]
  }
  
  func generateKeys() async throws -> PublicKeyBundle {
      // ...
      return PublicKeyBundle(
+         identitySigningKey: identitySigningKey.publicKey...,  // ✅
          identityKey: identityKey.publicKey...,                // ✅
          signedPrekey: signedPrekey.publicKey...,
          signedPrekeySignature: signature...,
          oneTimePrekeys: oneTimePrekeyPublics
      )
  }
```

### 2. APIClient.swift
```diff
  struct UploadSignalKeysRequest: Codable {
+     let identitySigningKey: String  // ✅ Ed25519
      let identityKey: String          // ✅ Curve25519
      let signedPrekey: String
      let signedPrekeySignature: String
      let oneTimePrekeys: [OneTimePrekeyData]
  }
  
  func uploadSignalKeys(bundle: PublicKeyBundle) async throws {
      let body = UploadSignalKeysRequest(
+         identitySigningKey: bundle.identitySigningKey,  // ✅
          identityKey: bundle.identityKey,                // ✅
          signedPrekey: bundle.signedPrekey,
          signedPrekeySignature: bundle.signedPrekeySignature,
          oneTimePrekeys: prekeyData
      )
  }
```

---

## ✅ Result

### Complete Key Package Sent to Backend

```
┌─────────────────────────────────────────────────────────┐
│              iOS → Backend Key Upload                   │
└─────────────────────────────────────────────────────────┘

Ed25519 Signing Key (32 bytes)
    ↓
    Used for: Signature verification
    Backend stores as: identitySigningKey
    ✅ Sent!

Curve25519 Key Agreement (32 bytes)
    ↓
    Used for: Key exchange, encryption
    Backend stores as: identityKey
    ✅ Sent!

Signed Prekey (32 bytes)
    ↓
    Signed with: Ed25519 signing key
    Backend verifies with: identitySigningKey
    ✅ Sent!

Signature (64 bytes)
    ↓
    Generated by: Ed25519 signing key
    Backend verifies: signedPrekey signature
    ✅ Sent!

100 One-Time Prekeys
    ↓
    Each 32 bytes Curve25519
    Used for: Initial session establishment
    ✅ Sent!
```

---

## 🚀 Next Steps

1. **Clean build** (⌘⇧K)
2. **Erase simulator** (Device → Erase All)
3. **Run app** (⌘R)
4. **Register new account**
5. **Check backend logs:**
   ```
   ✅ Received identitySigningKey (Ed25519)
   ✅ Received identityKey (Curve25519)
   ✅ Signature verification: PASSED
   ✅ Keys stored successfully
   ```

**Backend artık her iki key'i de alacak!** 🎉🔑
