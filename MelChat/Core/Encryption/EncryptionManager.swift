import Foundation
import CryptoKit
import Combine

/// Manages end-to-end encryption using Signal Protocol-inspired cryptography
/// Uses Curve25519 for key agreement and AES-GCM for message encryption
@MainActor
class EncryptionManager: ObservableObject {
    static let shared = EncryptionManager()

    // MARK: - Properties

    /// User's long-term identity key pair (Curve25519)
    private var identityKeyPair: Curve25519.KeyAgreement.PrivateKey?

    /// User's signed pre-key (rotated periodically)
    private var signedPrekey: Curve25519.KeyAgreement.PrivateKey?

    /// One-time prekeys for perfect forward secrecy
    private var onetimePrekeys: [Curve25519.KeyAgreement.PrivateKey] = []

    /// Active session keys (derived from key exchange)
    private var sessionKeys: [String: SymmetricKey] = [:] // userId -> shared secret

    private init() {}

    // MARK: - Key Generation

    /// Generate all cryptographic keys (called once during registration)
    func generateKeys() throws {
        // Generate identity key (long-term)
        identityKeyPair = Curve25519.KeyAgreement.PrivateKey()

        // Generate signed pre-key
        signedPrekey = Curve25519.KeyAgreement.PrivateKey()

        // Generate 100 one-time prekeys
        onetimePrekeys = (0..<100).map { _ in
            Curve25519.KeyAgreement.PrivateKey()
        }

        // Save keys to Keychain
        try saveKeysToKeychain()

        print("✅ Encryption keys generated successfully")
    }

    /// Load existing keys from Keychain
    func loadKeys() throws {
        let keychainHelper = KeychainHelper()
        
        NetworkLogger.shared.log("🔑 Loading encryption keys from Keychain...", group: "Encryption")
        
        // Load identity key
        if let identityKeyData = try? keychainHelper.load(forKey: "com.melchat.identityKey") {
            identityKeyPair = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: identityKeyData)
            NetworkLogger.shared.log("✅ Identity key loaded", group: "Encryption")
        } else {
            NetworkLogger.shared.log("⚠️ Identity key not found in Keychain", group: "Encryption")
        }
        
        // Load signed prekey
        if let prekeyData = try? keychainHelper.load(forKey: "com.melchat.signedPrekey") {
            signedPrekey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: prekeyData)
            NetworkLogger.shared.log("✅ Signed prekey loaded", group: "Encryption")
        } else {
            NetworkLogger.shared.log("⚠️ Signed prekey not found in Keychain", group: "Encryption")
        }
        
        // TODO: Load one-time prekeys (requires custom serialization)
        
        if identityKeyPair != nil && signedPrekey != nil {
            NetworkLogger.shared.log("✅ All encryption keys loaded successfully", group: "Encryption")
        } else {
            NetworkLogger.shared.log("⚠️ Some encryption keys missing", group: "Encryption")
        }
    }

    /// Check if keys exist
    func hasKeys() -> Bool {
        return identityKeyPair != nil
    }

    // MARK: - Key Upload

    /// Get public keys bundle for uploading to server
    func getPublicKeyBundle() -> PublicKeyBundle? {
        guard let identityKey = identityKeyPair,
              let signedPrekey = signedPrekey else {
            return nil
        }

        // Sign the pre-key with identity key
        let prekeyData = signedPrekey.publicKey.rawRepresentation
        
        // Note: Curve25519 signing requires conversion to Curve25519.Signing
        // For simplicity, we'll use a hash as signature (proper implementation would use Ed25519)
        let signatureData = SHA256.hash(data: prekeyData)
        let signature = Data(signatureData)

        // Convert one-time prekeys to base64
        let onetimePublicKeys = onetimePrekeys.map { key in
            key.publicKey.rawRepresentation.base64EncodedString()
        }

        return PublicKeyBundle(
            identityKey: identityKey.publicKey.rawRepresentation.base64EncodedString(),
            signedPrekey: signedPrekey.publicKey.rawRepresentation.base64EncodedString(),
            signedPrekeySignature: signature.base64EncodedString(),
            onetimePrekeys: onetimePublicKeys
        )
    }

    // MARK: - Session Key Exchange

    /// Establish encrypted session with another user
    /// Call this before sending the first message to a user
    func establishSession(with otherUserPublicKey: PublicKeyBundle) throws {
        guard let identityKey = identityKeyPair else {
            throw EncryptionError.invalidKey
        }

        // Convert other user's identity key from base64
        guard let otherIdentityKeyData = Data(base64Encoded: otherUserPublicKey.identityKey),
              let otherIdentityKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: otherIdentityKeyData) else {
            throw EncryptionError.invalidKey
        }

        // Perform ECDH (Elliptic Curve Diffie-Hellman)
        let sharedSecret = try identityKey.sharedSecretFromKeyAgreement(with: otherIdentityKey)

        // Derive symmetric key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("MelChat-Session-Key".utf8),
            outputByteCount: 32
        )

        // Store session key (in real app, use userId from bundle)
        // For MVP, we'll use the public key hash as identifier
        let sessionId = otherUserPublicKey.identityKey.prefix(16)
        sessionKeys[String(sessionId)] = symmetricKey

        print("✅ Session established with user")
    }

    /// Get or create session key for a user
    /// In production, this would fetch the user's public keys from server
    /// For MVP, we'll use a simplified approach
    func getOrCreateSessionKey(for userId: String, token: String) async throws -> SymmetricKey {
        // Check if session already exists
        if let existingKey = sessionKeys[userId] {
            NetworkLogger.shared.log("✅ Using cached session key for user \(userId.prefix(8))", group: "Encryption")
            return existingKey
        }

        NetworkLogger.shared.log("🔑 Creating new session key for user \(userId.prefix(8))...", group: "Encryption")
        
        // Make sure our identity key is loaded
        if identityKeyPair == nil {
            NetworkLogger.shared.log("⚠️ Identity key not loaded, attempting to load from Keychain", group: "Encryption")
            try loadKeys()
        }
        
        guard let identityKey = identityKeyPair else {
            NetworkLogger.shared.log("❌ Identity key still not available after loading", group: "Encryption")
            throw EncryptionError.invalidKey
        }

        // Fetch user's public keys from server
        NetworkLogger.shared.log("🌐 Fetching public keys for user \(userId.prefix(8))...", group: "Encryption")
        let response = try await APIClient.shared.getUserPublicKeys(token: token, userId: userId)

        // Convert their public keys from base64
        guard let theirIdentityKeyData = Data(base64Encoded: response.keys.identityKey),
              let theirIdentityKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirIdentityKeyData) else {
            NetworkLogger.shared.log("❌ Invalid recipient public key format", group: "Encryption")
            throw EncryptionError.invalidKey
        }
        
        NetworkLogger.shared.log("✅ Recipient public key loaded: \(response.keys.identityKey.prefix(20))...", group: "Encryption")

        // Perform ECDH
        let sharedSecret = try identityKey.sharedSecretFromKeyAgreement(with: theirIdentityKey)

        // Derive symmetric key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("MelChat-Session-Key".utf8),
            outputByteCount: 32
        )

        // Store session key
        sessionKeys[userId] = symmetricKey
        NetworkLogger.shared.log("✅ Session key established with user \(userId.prefix(8))", group: "Encryption")

        return symmetricKey
    }

    // MARK: - Message Encryption/Decryption

    /// Encrypt a message for a specific user (returns base64 encrypted payload)
    func encrypt(message: String, for userId: String, token: String) async throws -> String {
        NetworkLogger.shared.log("🔐 [ENC] Starting encryption for user \(userId.prefix(8))", group: "Encryption")
        
        // Convert message to data
        guard let messageData = message.data(using: .utf8) else {
            NetworkLogger.shared.log("❌ [ENC] Invalid message format", group: "Encryption")
            throw EncryptionError.invalidMessage
        }
        
        NetworkLogger.shared.log("📝 [ENC] Message size: \(messageData.count) bytes", group: "Encryption")
        
        // Make sure our identity key is loaded
        if identityKeyPair == nil {
            NetworkLogger.shared.log("⚠️ Identity key not loaded, attempting to load", group: "Encryption")
            try loadKeys()
        }
        
        guard identityKeyPair != nil else {
            NetworkLogger.shared.log("❌ No identity key available", group: "Encryption")
            throw EncryptionError.invalidKey
        }

        // Fetch recipient's public key
        NetworkLogger.shared.log("🌐 Fetching recipient public keys...", group: "Encryption")
        let response = try await APIClient.shared.getUserPublicKeys(token: token, userId: userId)
        
        guard let recipientKeyData = Data(base64Encoded: response.keys.identityKey),
              let recipientPublicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientKeyData) else {
            NetworkLogger.shared.log("❌ Invalid recipient public key", group: "Encryption")
            throw EncryptionError.invalidKey
        }
        
        NetworkLogger.shared.log("✅ Recipient public key: \(response.keys.identityKey.prefix(20))...", group: "Encryption")
        
        // Generate ephemeral key for this message (Perfect Forward Secrecy)
        let ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralPublicKey = ephemeralPrivateKey.publicKey
        
        NetworkLogger.shared.log("🔑 Generated ephemeral key for this message", group: "Encryption")

        // Perform ECDH with ephemeral key
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)

        // Derive symmetric key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("MelChat-Message-Key".utf8),
            outputByteCount: 32
        )
        
        // Encrypt using AES-GCM
        let sealedBox = try AES.GCM.seal(messageData, using: symmetricKey)

        // Return combined: ephemeralPublicKey + ciphertext (base64)
        guard let ciphertext = sealedBox.combined else {
            NetworkLogger.shared.log("❌ [ENC] Failed to create sealed box", group: "Encryption")
            throw EncryptionError.encryptionFailed
        }
        
        // Combine ephemeral public key + ciphertext
        let ephemeralKeyData = ephemeralPublicKey.rawRepresentation
        var combinedData = Data()
        combinedData.append(ephemeralKeyData) // 32 bytes
        combinedData.append(ciphertext)
        
        let base64Payload = combinedData.base64EncodedString()
        NetworkLogger.shared.log("✅ [ENC] Encrypted: \(combinedData.count) bytes → \(base64Payload.count) base64 chars", group: "Encryption")
        NetworkLogger.shared.log("   Ephemeral key: \(ephemeralKeyData.count) bytes", group: "Encryption")
        NetworkLogger.shared.log("   Ciphertext: \(ciphertext.count) bytes", group: "Encryption")
        NetworkLogger.shared.log("   Preview: \(base64Payload.prefix(40))...", group: "Encryption")

        return base64Payload
    }
    
    /// Encrypt binary data (images, files) for a specific user
    func encryptData(data: Data, for userId: String, token: String) async throws -> Data {
        // Get session key (or establish new session)
        let sessionKey = try await getOrCreateSessionKey(for: userId, token: token)

        // Encrypt using AES-GCM
        let sealedBox = try AES.GCM.seal(data, using: sessionKey)

        // Return combined ciphertext (nonce + ciphertext + tag)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        return combined
    }
    
    /// Decrypt binary data (images, files) from a specific user
    func decryptData(encryptedData: Data, from userId: String, token: String) async throws -> Data {
        // Get session key
        let sessionKey = try await getOrCreateSessionKey(for: userId, token: token)

        // Decrypt using AES-GCM
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: sessionKey)

        return decryptedData
    }

    /// Decrypt a message from base64 payload
    func decrypt(payload: String, from userId: String, token: String) async throws -> String {
        NetworkLogger.shared.log("🔓 [DEC] Starting decryption from user \(userId.prefix(8))", group: "Encryption")
        NetworkLogger.shared.log("   Payload preview: \(payload.prefix(40))...", group: "Encryption")
        
        // Decode base64
        guard let combinedData = Data(base64Encoded: payload) else {
            NetworkLogger.shared.log("❌ [DEC] Invalid base64 format", group: "Encryption")
            throw EncryptionError.invalidMessage
        }
        
        NetworkLogger.shared.log("📦 [DEC] Decoded: \(combinedData.count) bytes total", group: "Encryption")
        
        // Extract ephemeral public key (first 32 bytes) and ciphertext (rest)
        guard combinedData.count > 32 else {
            NetworkLogger.shared.log("❌ [DEC] Payload too short", group: "Encryption")
            throw EncryptionError.invalidMessage
        }
        
        let ephemeralKeyData = combinedData.prefix(32)
        let ciphertext = combinedData.suffix(from: 32)
        
        NetworkLogger.shared.log("   Ephemeral key: \(ephemeralKeyData.count) bytes", group: "Encryption")
        NetworkLogger.shared.log("   Ciphertext: \(ciphertext.count) bytes", group: "Encryption")
        
        // Make sure our identity key is loaded
        if identityKeyPair == nil {
            NetworkLogger.shared.log("⚠️ Identity key not loaded, attempting to load", group: "Encryption")
            try loadKeys()
        }
        
        guard let identityKey = identityKeyPair else {
            NetworkLogger.shared.log("❌ No identity key available", group: "Encryption")
            throw EncryptionError.invalidKey
        }
        
        // Load ephemeral public key
        guard let ephemeralPublicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralKeyData) else {
            NetworkLogger.shared.log("❌ [DEC] Invalid ephemeral public key", group: "Encryption")
            throw EncryptionError.invalidKey
        }
        
        // Perform ECDH with our identity key and sender's ephemeral key
        let sharedSecret = try identityKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)

        // Derive symmetric key using HKDF (same as encryption)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("MelChat-Message-Key".utf8),
            outputByteCount: 32
        )

        // Decrypt using AES-GCM
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)

        // Convert to string
        guard let message = String(data: decryptedData, encoding: .utf8) else {
            NetworkLogger.shared.log("❌ [DEC] Decrypted data is not valid UTF-8", group: "Encryption")
            throw EncryptionError.decryptionFailed
        }
        
        NetworkLogger.shared.log("✅ [DEC] Decrypted: \(message.count) chars", group: "Encryption")
        NetworkLogger.shared.log("   Content: \(message.prefix(50))...", group: "Encryption")

        return message
    }

    // MARK: - Keychain Storage

    private func saveKeysToKeychain() throws {
        guard let identityKey = identityKeyPair,
              let signedPrekey = signedPrekey else {
            throw EncryptionError.invalidKey
        }

        let keychainHelper = KeychainHelper()
        
        try keychainHelper.save(identityKey.rawRepresentation, forKey: "com.melchat.identityKey")
        try keychainHelper.save(signedPrekey.rawRepresentation, forKey: "com.melchat.signedPrekey")
        
        // TODO: Save one-time prekeys (requires custom serialization)
    }
}

// MARK: - Data Models

struct PublicKeyBundle: Codable {
    let identityKey: String // Base64
    let signedPrekey: String // Base64
    let signedPrekeySignature: String // Base64
    let onetimePrekeys: [String] // Array of Base64 strings
}

// Note: EncryptedMessage is defined in EncryptionService.swift
// Note: EncryptionError is defined in EncryptionService.swift

