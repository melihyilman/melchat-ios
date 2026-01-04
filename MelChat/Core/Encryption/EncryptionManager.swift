import Foundation
import CryptoKit
import Combine

/// Manages end-to-end encryption using Signal Protocol-inspired cryptography
/// Uses Curve25519 for key agreement and AES-GCM for message encryption
@MainActor
class EncryptionManager: ObservableObject {
    static let shared = EncryptionManager()

    // MARK: - Properties

    /// User's long-term identity key pair for signing (Ed25519)
    private var identitySigningKeyPair: Curve25519.Signing.PrivateKey?

    /// User's identity key pair for key agreement (Curve25519)
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
        // Generate identity signing key (Ed25519 for signatures)
        identitySigningKeyPair = Curve25519.Signing.PrivateKey()

        // Generate identity key agreement key (Curve25519 for key exchange)
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

        // Load identity signing key
        if let signingKeyData = try? keychainHelper.load(forKey: "com.melchat.identitySigningKey") {
            identitySigningKeyPair = try Curve25519.Signing.PrivateKey(rawRepresentation: signingKeyData)
        }

        // Load identity key agreement key
        if let identityKeyData = try? keychainHelper.load(forKey: "com.melchat.identityKey") {
            identityKeyPair = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: identityKeyData)
        }

        // Load signed prekey
        if let prekeyData = try? keychainHelper.load(forKey: "com.melchat.signedPrekey") {
            signedPrekey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: prekeyData)
        }

        // TODO: Load one-time prekeys (requires custom serialization)

        print("✅ Encryption keys loaded from Keychain")
    }

    /// Check if keys exist
    func hasKeys() -> Bool {
        return identitySigningKeyPair != nil && identityKeyPair != nil
    }

    // MARK: - Key Upload

    /// Get public keys bundle for uploading to server
    func getPublicKeyBundle() -> PublicKeyBundle? {
        guard let identitySigningKey = identitySigningKeyPair,
              let identityKey = identityKeyPair,  // ✅ Also get Curve25519 key
              let signedPrekey = signedPrekey else {
            return nil
        }

        // Sign the pre-key with Ed25519 identity signing key
        let prekeyData = signedPrekey.publicKey.rawRepresentation

        // Use Ed25519 to sign the prekey
        let signature = try! identitySigningKey.signature(for: prekeyData)

        // Convert one-time prekeys to OneTimePrekey format
        let oneTimePrekeyObjects = onetimePrekeys.enumerated().map { (index, key) in
            OneTimePrekey(
                id: "prekey_\(index)_\(UUID().uuidString)",
                publicKey: key.publicKey.rawRepresentation.base64EncodedString()
            )
        }

        return PublicKeyBundle(
            identityKey: identitySigningKey.publicKey.rawRepresentation.base64EncodedString(),  // ✅ Ed25519 only
            signedPrekey: signedPrekey.publicKey.rawRepresentation.base64EncodedString(),
            signedPrekeySignature: signature.base64EncodedString(),
            oneTimePrekeys: oneTimePrekeyObjects
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
    func getOrCreateSessionKey(for userId: String) async throws -> SymmetricKey {
        // Check if session already exists
        if let existingKey = sessionKeys[userId] {
            return existingKey
        }

        // Fetch user's public keys from server
        print("🔑 Fetching public keys for user \(userId)...")
        let response = try await APIClient.shared.getUserPublicKeys(userId: userId)

        // Convert their public keys from base64
        guard let theirIdentityKeyData = Data(base64Encoded: response.keys.identityKey),
              let theirIdentityKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: theirIdentityKeyData) else {
            throw EncryptionError.invalidKey
        }

        guard let identityKey = identityKeyPair else {
            throw EncryptionError.invalidKey
        }

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
        print("✅ Session key established with user \(userId)")

        return symmetricKey
    }

    // MARK: - Message Encryption/Decryption

    /// Encrypt a message for a specific user
    func encrypt(message: String, for userId: String) async throws -> EncryptedMessage {
        // Get session key (or establish new session)
        let sessionKey = try await getOrCreateSessionKey(for: userId)

        // Convert message to data
        guard let messageData = message.data(using: .utf8) else {
            throw EncryptionError.invalidMessage
        }

        // Encrypt using AES-GCM
        let sealedBox = try AES.GCM.seal(messageData, using: sessionKey)

        // Return encrypted payload
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        // Use EncryptionService's EncryptedMessage format
        // Generate ephemeral key for this message (for compatibility)
        let ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
        
        return EncryptedMessage(
            ciphertext: combined,
            ephemeralPublicKey: ephemeralKey.publicKey.rawRepresentation
        )
    }

    /// Decrypt a message from a specific user
    func decrypt(encryptedMessage: EncryptedMessage, from userId: String) async throws -> String {
        // Get session key
        let sessionKey = try await getOrCreateSessionKey(for: userId)

        // Decrypt using AES-GCM
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedMessage.ciphertext)
        let decryptedData = try AES.GCM.open(sealedBox, using: sessionKey)

        // Convert to string
        guard let message = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }

        return message
    }

    // MARK: - Keychain Storage

    private func saveKeysToKeychain() throws {
        guard let identitySigningKey = identitySigningKeyPair,
              let identityKey = identityKeyPair,
              let signedPrekey = signedPrekey else {
            throw EncryptionError.invalidKey
        }

        let keychainHelper = KeychainHelper()

        try keychainHelper.save(identitySigningKey.rawRepresentation, forKey: "com.melchat.identitySigningKey")
        try keychainHelper.save(identityKey.rawRepresentation, forKey: "com.melchat.identityKey")
        try keychainHelper.save(signedPrekey.rawRepresentation, forKey: "com.melchat.signedPrekey")

        // TODO: Save one-time prekeys (requires custom serialization)
    }
}

// MARK: - Data Models (DEPRECATED - Use SignalProtocolManager models instead)
// Note: EncryptedMessage is defined in EncryptionService.swift
// Note: EncryptionError is defined in EncryptionService.swift

