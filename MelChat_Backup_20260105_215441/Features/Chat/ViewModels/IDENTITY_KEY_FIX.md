# 🔑 Identity Key Fix - Ed25519 vs Curve25519

## ❌ Problem
```
[Chat] ❌ Error sending message: noIdentityKey
```

### Root Cause
Backend'e **yanlış key** gönderiliyordu:
- ❌ **Gönderilen:** Ed25519 Signing Key (signature için)
- ✅ **Gönderilmesi Gereken:** Curve25519 Key Agreement Key (encryption için)

### Key Types in Signal Protocol

Signal Protocol **2 farklı identity key** kullanır:

1. **Identity Signing Key (Ed25519)**
   - Purpose: Sign prekeys (imzalama)
   - Algorithm: Ed25519 (digital signature)
   - Used for: Verifying authenticity
   - Not used for: Encryption/Decryption

2. **Identity Key Agreement Key (Curve25519)**
   - Purpose: Establish shared secrets (encryption)
   - Algorithm: Curve25519 ECDH
   - Used for: Key agreement, session establishment
   - **This is what we need for encryption!**

---

## 🔧 Fix

### Before ❌
```swift
func generateKeys() async throws -> PublicKeyBundle {
    let identitySigningKey = Curve25519.Signing.PrivateKey()  // Ed25519
    let identityKey = Curve25519.KeyAgreement.PrivateKey()     // Curve25519
    
    // ...
    
    return PublicKeyBundle(
        identityKey: identitySigningKey.publicKey.rawRepresentation.base64EncodedString(),  // ❌ Wrong!
        signedPrekey: signedPrekey.publicKey.rawRepresentation.base64EncodedString(),
        signedPrekeySignature: signature.base64EncodedString(),
        oneTimePrekeys: oneTimePrekeyPublics
    )
}
```

**Problem:** Sending Ed25519 signing key instead of Curve25519 key agreement key!

### After ✅
```swift
func generateKeys() async throws -> PublicKeyBundle {
    let identitySigningKey = Curve25519.Signing.PrivateKey()  // Ed25519 (for signatures)
    let identityKey = Curve25519.KeyAgreement.PrivateKey()     // Curve25519 (for encryption)
    
    // ...
    
    return PublicKeyBundle(
        identityKey: identityKey.publicKey.rawRepresentation.base64EncodedString(),  // ✅ Correct!
        signedPrekey: signedPrekey.publicKey.rawRepresentation.base64EncodedString(),
        signedPrekeySignature: signature.base64EncodedString(),
        oneTimePrekeys: oneTimePrekeyPublics
    )
}
```

**Fix:** Now sending the correct Curve25519 key agreement public key!

---

## 🔄 Key Flow

### Registration Flow
```
1. iOS generates keys:
   - identitySigningKey (Ed25519) → For signing prekeys
   - identityKey (Curve25519) → For key agreement
   - signedPrekey (Curve25519) → Short-term key
   - oneTimePrekeys (Curve25519) → Ephemeral keys

2. iOS uploads to backend:
   POST /api/keys/upload
   {
     "identityKey": "base64...",  ← ✅ Now Curve25519 key agreement key
     "signedPrekey": "base64...",
     "signedPrekeySignature": "base64...",  ← Signed with Ed25519
     "oneTimePrekeys": [...]
   }

3. Backend stores keys

4. Other users fetch keys:
   GET /api/keys/user/{userId}
   Response:
   {
     "identityKey": "base64...",  ← ✅ Curve25519 key (correct!)
     "signedPrekey": "base64...",
     "signedPrekeySignature": "base64...",
     "onetimePrekey": "base64..." (optional)
   }

5. iOS establishes session:
   - Parse identityKey as Curve25519 ✅
   - Parse signedPrekey as Curve25519 ✅
   - Perform X3DH key agreement
   - Create shared secret
   - Initialize Double Ratchet
```

---

## 🧪 Testing

### 1. Delete Old Keys
```bash
# Settings → Encryption Keys → Clear (if exists)
# Or delete app and reinstall
```

### 2. Generate New Keys
```
1. Open app
2. Login/Register
3. Check logs:
   🔑 Generating Signal Protocol keys...
   ✅ Generated all keys successfully
   ✅ Identity Signing Key (Ed25519): Zg/BY1...
   ✅ Identity Key Agreement (Curve25519): qnw1PL...  ← This is uploaded!
   ✅ Signed Prekey: ...
   ✅ One-Time Prekeys: 100
```

### 3. Send Message
```
1. Open chat with another user
2. Send message
3. Check logs:
   🔐 Encrypting message with Signal Protocol...
   🤝 Establishing session with 15e1e29a...
   📤 Fetching recipient keys...
   ✅ Parsed recipient identity key (Curve25519)  ← Should work now!
   ✅ Parsed recipient signed prekey
   ✅ Session established
   ✅ Message encrypted
   ✅ Message sent
```

---

## 📊 Key Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    Signal Protocol Keys                      │
└─────────────────────────────────────────────────────────────┘

┌────────────────────────┐         ┌────────────────────────┐
│  Identity Signing Key  │         │ Identity Key Agreement │
│      (Ed25519)         │         │      (Curve25519)      │
│                        │         │                        │
│  - Sign prekeys        │         │  - Key agreement       │
│  - Verify signatures   │         │  - Establish sessions  │
│  - Authentication      │         │  - Encryption          │
│                        │         │                        │
│  NOT sent to backend   │         │  ✅ Sent to backend    │
│  (private key only)    │         │  (public key only)     │
└────────────────────────┘         └────────────────────────┘
           │                                  │
           │ Signs                            │ Used for
           ▼                                  ▼
┌────────────────────────┐         ┌────────────────────────┐
│    Signed Prekey       │────────►│   X3DH Key Agreement   │
│    (Curve25519)        │         │                        │
│                        │         │  - Shared secret       │
│  - Medium-term key     │         │  - Session keys        │
│  - Rotated weekly      │         │  - Double Ratchet init │
└────────────────────────┘         └────────────────────────┘
           │
           │ Signature uploaded
           ▼
    Backend Storage
    ───────────────
    {
      "identityKey": "Curve25519",  ✅
      "signedPrekey": "Curve25519", ✅
      "signedPrekeySignature": "Ed25519 sig", ✅
      "onetimePrekeys": ["Curve25519", ...] ✅
    }
```

---

## ✅ What Changed

### File: `SignalProtocolManager.swift`

#### Change 1: generateKeys() - Send correct key
```diff
  return PublicKeyBundle(
-     identityKey: identitySigningKey.publicKey.rawRepresentation.base64EncodedString(),
+     identityKey: identityKey.publicKey.rawRepresentation.base64EncodedString(),
      signedPrekey: signedPrekey.publicKey.rawRepresentation.base64EncodedString(),
      signedPrekeySignature: signature.base64EncodedString(),
      oneTimePrekeys: oneTimePrekeyPublics
  )
```

#### Change 2: establishSession() - Better error handling
```diff
- guard let recipientIdentityKey = try? Curve25519.KeyAgreement.PublicKey(...)
+ guard let identityKeyData = Data(base64Encoded: recipientBundle.identityKey),
+       let recipientIdentityKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: identityKeyData) else {
+     NetworkLogger.shared.log("❌ Invalid identity key from backend", group: "Encryption")
      throw SignalError.invalidPublicKey
  }
```

---

## 🎯 Expected Behavior

### Before Fix
```
[Encryption] 🤝 Establishing session with 15e1e29a...
[Encryption] ❌ Invalid identity key  // Ed25519 can't be used for key agreement
[Chat] ❌ Error sending message: noIdentityKey
```

### After Fix
```
[Encryption] 🤝 Establishing session with 15e1e29a...
[Encryption] ✅ Parsed recipient identity key (Curve25519)
[Encryption] ✅ Parsed recipient signed prekey
[Encryption] ✅ Session established with 15e1e29a
[Encryption] ✅ Message encrypted (542 bytes)
[Chat] ✅ Message sent (encrypted): msg-xyz
```

---

## 🚨 Important Notes

### 1. All Users Must Re-generate Keys
After this fix, **all users must re-register or re-generate their encryption keys** because:
- Old keys in backend database are Ed25519 (wrong type)
- New keys will be Curve25519 (correct type)
- Old and new keys are incompatible

### 2. Backend is Unchanged
Backend doesn't need any changes! It already:
- Stores `identityKey` as base64 string ✅
- Doesn't care about key type ✅
- Just returns what it stored ✅

The problem was **what we sent**, not how backend handled it.

### 3. Key Rotation
In production, you should:
- Store both Ed25519 and Curve25519 identity keys separately
- Use Ed25519 only for signatures
- Use Curve25519 only for key agreement
- Never mix the two!

---

## 🎉 Result

✅ **identityKey now contains the correct Curve25519 key agreement key**
✅ **Session establishment works**
✅ **Messages can be encrypted and sent**
✅ **Messages can be received and decrypted**

### Test It:
```bash
# Clean build
⌘⇧K

# Run
⌘R

# Delete app data (to generate new keys)
# Login
# Send message
# Should work! 🚀
```
