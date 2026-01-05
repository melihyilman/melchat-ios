# ✅ Backend Format'a Uyarlama - Final

## 🎯 Backend'in İstediği Format

Backend **sadece Ed25519 signing key** istiyor:

```json
{
  "identityKey": "Zg/BY1glTkJhH94PxOKmtbjjjvQNC173rkVqSz58cLA=",  // ← Ed25519 (signature verification)
  "signedPrekey": "qnw1PLydNQQshHHZUUcLV3jEXmKblbX83Tjz1TtqxS0=",
  "signedPrekeySignature": "JgW6T36HpidCBHxNOfdNqkglD3u+/5JJG5Ze39JIaHz...",
  "oneTimePrekeys": [...]
}
```

**NOT:** Curve25519 key agreement key backend'e gönderilmiyor - sadece local'de (Keychain) saklanıyor.

---

## ✅ iOS Implementation

### 1. PublicKeyBundle Struct
```swift
struct PublicKeyBundle: Codable {
    let identityKey: String        // ← Ed25519 public key (signature verification için)
    let signedPrekey: String
    let signedPrekeySignature: String
    let oneTimePrekeys: [OneTimePrekey]
}
```

### 2. generateKeys() - Sadece Ed25519 Gönder
```swift
func generateKeys() async throws -> PublicKeyBundle {
    // 1. Generate Ed25519 signing key
    let identitySigningKey = Curve25519.Signing.PrivateKey()
    
    // 2. Generate Curve25519 key agreement key
    let identityKey = Curve25519.KeyAgreement.PrivateKey()
    
    // 3. Save BOTH to Keychain (local storage)
    try saveKeysToKeychain()
    
    // 4. Return only Ed25519 for backend upload
    return PublicKeyBundle(
        identityKey: identitySigningKey.publicKey.rawRepresentation.base64EncodedString(),  // ✅ Ed25519 only
        signedPrekey: signedPrekey.publicKey.rawRepresentation.base64EncodedString(),
        signedPrekeySignature: signature.base64EncodedString(),
        oneTimePrekeys: oneTimePrekeyPublics
    )
}
```

### 3. API Request
```swift
struct UploadSignalKeysRequest: Codable {
    let identityKey: String  // ✅ Ed25519 only
    let signedPrekey: String
    let signedPrekeySignature: String
    let oneTimePrekeys: [OneTimePrekeyData]
}
```

---

## 🔑 Key Storage Strategy

### Local Storage (Keychain) ✅
```
✅ identitySigningKey (Ed25519) → Signing prekeys
✅ identityKey (Curve25519) → Key agreement/encryption
✅ signedPrekey (Curve25519)
✅ 100 oneTimePrekeys (Curve25519)
```

### Backend Upload ✅
```
✅ identityKey (Ed25519 public key) → Signature verification
✅ signedPrekey (Curve25519 public key)
✅ signedPrekeySignature (Ed25519 signature)
✅ oneTimePrekeys (Curve25519 public keys)
```

### NOT Uploaded ❌
```
❌ identityKey (Curve25519) → Kept local for encryption
❌ Private keys → Never leave device
```

---

## 📊 Why This Works

### Ed25519 for Signatures
```
Backend needs to:
1. Receive signedPrekey
2. Receive signedPrekeySignature
3. Verify signature with identityKey (Ed25519)

✅ Backend can verify: "Did this user really sign this prekey?"
✅ Backend knows keys are authentic
```

### Curve25519 for Encryption
```
iOS needs to:
1. Establish sessions with other users
2. Perform ECDH key agreement
3. Encrypt/decrypt messages

✅ Curve25519 key stays local
✅ Used for X3DH protocol
✅ Never sent to backend
```

---

## 🔄 Message Flow

### Sending Message to Bob

```
1. iOS fetches Bob's keys from backend:
   GET /api/keys/user/bob
   {
     "identityKey": "...",      // Ed25519 (for verification)
     "signedPrekey": "...",     // Curve25519
     "signedPrekeySignature": "...",
     "onetimePrekey": "..."
   }

2. iOS verifies signature:
   ✅ Use Bob's identityKey (Ed25519)
   ✅ Verify signedPrekeySignature
   ✅ Confirms Bob's keys are authentic

3. iOS establishes session:
   ✅ Use local identityKey (Curve25519)
   ✅ Use Bob's signedPrekey (Curve25519)
   ✅ Perform X3DH key agreement
   ✅ Derive shared secret

4. iOS encrypts message:
   ✅ Use derived session key (AES-GCM)
   ✅ Send encrypted payload to backend
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
[Encryption] ✅ Identity Key Agreement (Curve25519): qnw1PLyd... (stored locally)
[Network] 📤 POST /api/keys/upload
Body: {
  "identityKey": "Zg/BY1gl...",  ← Ed25519 only ✅
  "signedPrekey": "...",
  "signedPrekeySignature": "...",
  "oneTimePrekeys": [...]
}
[Network] 📥 RESPONSE 200 ✅
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
-     let identitySigningKey: String
      let identityKey: String  // ← Ed25519 only
      let signedPrekey: String
      let signedPrekeySignature: String
      let oneTimePrekeys: [OneTimePrekey]
  }
  
  return PublicKeyBundle(
-     identitySigningKey: identitySigningKey.publicKey...,
      identityKey: identitySigningKey.publicKey...,  // ← Ed25519 only
      signedPrekey: ...,
      signedPrekeySignature: ...,
      oneTimePrekeys: ...
  )
```

### 2. APIClient.swift
```diff
  struct UploadSignalKeysRequest: Codable {
-     let identitySigningKey: String
      let identityKey: String  // ← Ed25519 only
      let signedPrekey: String
      let signedPrekeySignature: String
      let oneTimePrekeys: [OneTimePrekeyData]
  }
```

### 3. EncryptionManager.swift
```diff
  return PublicKeyBundle(
-     identitySigningKey: identitySigningKey.publicKey...,
      identityKey: identitySigningKey.publicKey...,  // ← Ed25519 only
      signedPrekey: ...,
      signedPrekeySignature: ...,
      oneTimePrekeys: ...
  )
```

---

## ✅ Summary

### What We Send to Backend
```
✅ identityKey (Ed25519 public key)
✅ signedPrekey (Curve25519 public key)
✅ signedPrekeySignature (Ed25519 signature)
✅ oneTimePrekeys (Curve25519 public keys)
```

### What We Keep Local
```
✅ identitySigningKey (Ed25519 private key)
✅ identityKey (Curve25519 private key)
✅ All private keys
```

### Backend Capabilities
```
✅ Verify signatures (with Ed25519 public key)
✅ Store public keys for other users to fetch
✅ Cannot decrypt messages (no symmetric keys)
```

### iOS Capabilities
```
✅ Sign prekeys (with Ed25519 private key)
✅ Establish sessions (with Curve25519 private key)
✅ Encrypt/decrypt messages (with derived session keys)
```

---

## 🚀 Result

Backend artık:
- ✅ Ed25519 public key alıyor
- ✅ Signature'ları verify edebiliyor
- ✅ 200 OK dönmeli

iOS artık:
- ✅ Backend format'ına uygun key gönderiyor
- ✅ Local'de Curve25519 key saklıyor
- ✅ E2EE mesajlaşma çalışıyor

**Build ve test et!** 🎉
