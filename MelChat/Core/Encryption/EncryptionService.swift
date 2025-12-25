import Foundation
import CryptoKit

/// Simplified E2EE service using CryptoKit
/// TODO: Replace with Signal Protocol (libsignal-swift) for production
class EncryptionService {
    static let shared = EncryptionService()

    init() {}

    // MARK: - Key Generation

    /// Generate a new key pair for the user
    func generateKeyPair() -> KeyPair {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey

        return KeyPair(
            privateKey: privateKey.rawRepresentation,
            publicKey: publicKey.rawRepresentation
        )
    }

    // MARK: - Encryption

    /// Encrypt a message for a recipient
    func encrypt(
        message: String,
        recipientPublicKey: Data,
        senderPrivateKey: Data
    ) throws -> EncryptedMessage {
        guard let messageData = message.data(using: .utf8) else {
            throw EncryptionError.invalidMessage
        }

        // Generate ephemeral key for this message
        let ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralPublicKey = ephemeralPrivateKey.publicKey

        // Derive shared secret using ECDH
        let recipientKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: recipientPublicKey)
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: recipientKey)

        // Derive encryption key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: 32
        )

        // Encrypt with AES-GCM
        let sealedBox = try AES.GCM.seal(messageData, using: symmetricKey)

        guard let ciphertext = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        return EncryptedMessage(
            ciphertext: ciphertext,
            ephemeralPublicKey: ephemeralPublicKey.rawRepresentation
        )
    }

    // MARK: - Decryption

    /// Decrypt a message from a sender
    func decrypt(
        encryptedMessage: EncryptedMessage,
        recipientPrivateKey: Data,
        senderPublicKey: Data
    ) throws -> String {
        // Load recipient's private key
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: recipientPrivateKey)

        // Load ephemeral public key
        let ephemeralPublicKey = try Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: encryptedMessage.ephemeralPublicKey
        )

        // Derive shared secret
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey)

        // Derive decryption key
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: 32
        )

        // Decrypt with AES-GCM
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedMessage.ciphertext)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)

        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }

        return decryptedString
    }
}

// MARK: - Models

struct KeyPair: Codable {
    let privateKey: Data
    let publicKey: Data
}

struct EncryptedMessage: Codable {
    let ciphertext: Data
    let ephemeralPublicKey: Data
}

// MARK: - Errors

enum EncryptionError: LocalizedError {
    case invalidMessage
    case invalidKey
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidMessage:
            return "Invalid message format"
        case .invalidKey:
            return "Invalid encryption key"
        case .encryptionFailed:
            return "Failed to encrypt message"
        case .decryptionFailed:
            return "Failed to decrypt message"
        }
    }
}
