import Foundation
import CryptoKit

/// Basit E2E Encryption - Sadece Curve25519 + AES-GCM
@MainActor
class SimpleEncryption {
    static let shared = SimpleEncryption()
    
    private var myKeyPair: Curve25519.KeyAgreement.PrivateKey?
    private let keychainHelper = KeychainHelper()
    
    private init() {
        loadKeys()
    }
    
    // MARK: - Key Management
    
    /// Generate new key pair and return public key
    func generateKeys() -> String {
        let keyPair = Curve25519.KeyAgreement.PrivateKey()
        self.myKeyPair = keyPair
        
        // Save to Keychain
        try? keychainHelper.save(
            keyPair.rawRepresentation,
            forKey: "e2e.privateKey"
        )
        
        NetworkLogger.shared.log("✅ Generated Curve25519 key pair", group: "Encryption")
        
        // Return public key (base64)
        return keyPair.publicKey.rawRepresentation.base64EncodedString()
    }
    
    /// Load keys from Keychain
    func loadKeys() {
        guard let keyData = try? keychainHelper.load(forKey: "e2e.privateKey"),
              let keyPair = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData) else {
            NetworkLogger.shared.log("⚠️ No keys found in Keychain", group: "Encryption")
            return
        }
        
        self.myKeyPair = keyPair
        NetworkLogger.shared.log("✅ Loaded keys from Keychain", group: "Encryption")
    }
    
    /// Check if keys exist
    func hasKeys() -> Bool {
        return myKeyPair != nil
    }
    
    // MARK: - Encryption
    
    /// Encrypt message for recipient
    func encrypt(message: String, recipientPublicKey: String) throws -> String {
        guard let myKey = myKeyPair else {
            NetworkLogger.shared.log("❌ No private key available", group: "Encryption")
            throw EncryptionError.noPrivateKey
        }
        
        NetworkLogger.shared.log("🔐 Encrypting message...", group: "Encryption")
        
        // Parse recipient's public key
        guard let recipientPubKeyData = Data(base64Encoded: recipientPublicKey),
              let recipientPubKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientPubKeyData) else {
            throw EncryptionError.invalidPublicKey
        }
        
        // Perform ECDH to get shared secret
        let sharedSecret = try myKey.sharedSecretFromKeyAgreement(with: recipientPubKey)
        
        // Derive symmetric key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("MelChat".utf8),
            outputByteCount: 32
        )
        
        // Encrypt message with AES-GCM
        let messageData = Data(message.utf8)
        let sealedBox = try AES.GCM.seal(messageData, using: symmetricKey)
        
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        let ciphertext = combined.base64EncodedString()
        NetworkLogger.shared.log("✅ Message encrypted (\(combined.count) bytes)", group: "Encryption")
        
        return ciphertext
    }
    
    // MARK: - Decryption
    
    /// Decrypt message from sender
    func decrypt(ciphertext: String, senderPublicKey: String) throws -> String {
        guard let myKey = myKeyPair else {
            NetworkLogger.shared.log("❌ No private key available", group: "Encryption")
            throw EncryptionError.noPrivateKey
        }
        
        NetworkLogger.shared.log("🔓 Decrypting message...", group: "Encryption")
        
        // Parse sender's public key
        guard let senderPubKeyData = Data(base64Encoded: senderPublicKey),
              let senderPubKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderPubKeyData) else {
            throw EncryptionError.invalidPublicKey
        }
        
        // Perform ECDH to get same shared secret
        let sharedSecret = try myKey.sharedSecretFromKeyAgreement(with: senderPubKey)
        
        // Derive same symmetric key
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("MelChat".utf8),
            outputByteCount: 32
        )
        
        // Decrypt with AES-GCM
        guard let ciphertextData = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidCiphertext
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertextData)
        let plaintext = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        guard let message = String(data: plaintext, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        NetworkLogger.shared.log("✅ Message decrypted: \(message.prefix(50))...", group: "Encryption")
        
        return message
    }
}

// MARK: - Errors

enum EncryptionError: LocalizedError {
    case noPrivateKey
    case invalidPublicKey
    case invalidCiphertext
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .noPrivateKey:
            return "No private key available. Please generate keys first."
        case .invalidPublicKey:
            return "Invalid public key format"
        case .invalidCiphertext:
            return "Invalid ciphertext format"
        case .encryptionFailed:
            return "Failed to encrypt message"
        case .decryptionFailed:
            return "Failed to decrypt message"
        }
    }
}
