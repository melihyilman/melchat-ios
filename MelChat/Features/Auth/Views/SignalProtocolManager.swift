import Foundation
import CryptoKit

/// Proper Signal Protocol implementation for E2E encryption
/// Based on Signal's X3DH (Extended Triple Diffie-Hellman) + Double Ratchet
@MainActor
class SignalProtocolManager: ObservableObject {
    static let shared = SignalProtocolManager()
    
    // MARK: - Keys Storage
    
    /// Long-term identity key pair (never changes unless user reinstalls)
    private var identityKeyPair: Curve25519.KeyAgreement.PrivateKey?
    
    /// Signed prekey (rotated periodically for forward secrecy)
    private var signedPrekeyPair: Curve25519.KeyAgreement.PrivateKey?
    private var signedPrekeySignature: Data?
    
    /// One-time prekeys (each used once, then deleted)
    private var oneTimePrekeyPairs: [String: Curve25519.KeyAgreement.PrivateKey] = [:]
    
    /// Active sessions with other users
    private var sessions: [String: Session] = [:]
    
    private let keychainHelper = KeychainHelper()
    
    private init() {}
    
    // MARK: - Session Management
    
    struct Session {
        var rootKey: SymmetricKey
        var sendingChainKey: SymmetricKey
        var receivingChainKey: SymmetricKey
        var sendingChainLength: Int
        var receivingChainLength: Int
        var previousSendingChainLength: Int
        
        // Ratchet state
        var dhRatchetKeyPair: Curve25519.KeyAgreement.PrivateKey
        var dhRatchetRemotePublicKey: Curve25519.KeyAgreement.PublicKey?
    }
    
    // MARK: - Key Generation (Registration)
    
    /// Generate all keys during user registration
    /// Call this ONCE when user first signs up
    func generateKeys() throws -> PublicKeyBundle {
        NetworkLogger.shared.log("🔑 Generating Signal Protocol keys...", group: "Encryption")
        
        // 1. Generate long-term identity key pair
        let identityKey = Curve25519.KeyAgreement.PrivateKey()
        self.identityKeyPair = identityKey
        
        // 2. Generate signed prekey pair
        let signedPrekey = Curve25519.KeyAgreement.PrivateKey()
        self.signedPrekeyPair = signedPrekey
        
        // 3. Sign the prekey with identity key (using Ed25519 for signing)
        let identitySigningKey = try Curve25519.Signing.PrivateKey(rawRepresentation: identityKey.rawRepresentation)
        let prekeyData = signedPrekey.publicKey.rawRepresentation
        let signature = try identitySigningKey.signature(for: prekeyData)
        self.signedPrekeySignature = signature
        
        // 4. Generate 100 one-time prekeys
        NetworkLogger.shared.log("🔑 Generating 100 one-time prekeys...", group: "Encryption")
        for i in 0..<100 {
            let prekeyId = "prekey_\(i)_\(UUID().uuidString)"
            let oneTimePrekey = Curve25519.KeyAgreement.PrivateKey()
            oneTimePrekeyPairs[prekeyId] = oneTimePrekey
        }
        
        // 5. Save to Keychain
        try saveKeysToKeychain()
        
        NetworkLogger.shared.log("✅ Generated all keys successfully", group: "Encryption")
        NetworkLogger.shared.log("   Identity Key: \(identityKey.publicKey.rawRepresentation.base64EncodedString().prefix(20))...", group: "Encryption")
        NetworkLogger.shared.log("   Signed Prekey: \(signedPrekey.publicKey.rawRepresentation.base64EncodedString().prefix(20))...", group: "Encryption")
        NetworkLogger.shared.log("   One-Time Prekeys: \(oneTimePrekeyPairs.count)", group: "Encryption")
        
        // 6. Return public key bundle for backend upload
        let oneTimePrekeyPublics = oneTimePrekeyPairs.map { (id, key) in
            OneTimePrekey(
                id: id,
                publicKey: key.publicKey.rawRepresentation.base64EncodedString()
            )
        }
        
        return PublicKeyBundle(
            identityKey: identityKey.publicKey.rawRepresentation.base64EncodedString(),
            signedPrekey: signedPrekey.publicKey.rawRepresentation.base64EncodedString(),
            signedPrekeySignature: signature.base64EncodedString(),
            oneTimePrekeys: oneTimePrekeyPublics
        )
    }
    
    /// Load existing keys from Keychain
    func loadKeys() throws {
        NetworkLogger.shared.log("🔑 Loading keys from Keychain...", group: "Encryption")
        
        // Load identity key
        if let identityData = try? keychainHelper.load(forKey: "signal.identityKey") {
            identityKeyPair = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: identityData)
            NetworkLogger.shared.log("✅ Identity key loaded", group: "Encryption")
        } else {
            NetworkLogger.shared.log("⚠️ No identity key found", group: "Encryption")
        }
        
        // Load signed prekey
        if let prekeyData = try? keychainHelper.load(forKey: "signal.signedPrekey") {
            signedPrekeyPair = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: prekeyData)
            NetworkLogger.shared.log("✅ Signed prekey loaded", group: "Encryption")
        }
        
        // Load signature
        if let sigData = try? keychainHelper.load(forKey: "signal.signature") {
            signedPrekeySignature = sigData
            NetworkLogger.shared.log("✅ Signature loaded", group: "Encryption")
        }
        
        // Load one-time prekeys
        if let prekeyData = try? keychainHelper.load(forKey: "signal.oneTimePrekeys"),
           let prekeyDict = try? JSONDecoder().decode([String: Data].self, from: prekeyData) {
            for (id, keyData) in prekeyDict {
                if let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData) {
                    oneTimePrekeyPairs[id] = key
                }
            }
            NetworkLogger.shared.log("✅ Loaded \(oneTimePrekeyPairs.count) one-time prekeys", group: "Encryption")
        }
    }
    
    // MARK: - X3DH Key Agreement (First Message)
    
    /// Establish session with recipient (called before first message)
    func establishSession(with recipientBundle: RecipientKeyBundle) throws {
        guard let identityKey = identityKeyPair else {
            throw SignalError.noIdentityKey
        }
        
        NetworkLogger.shared.log("🤝 Establishing session with \(recipientBundle.userId.prefix(8))...", group: "Encryption")
        
        // 1. Parse recipient's public keys
        guard let recipientIdentityKey = try? Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: Data(base64Encoded: recipientBundle.identityKey)!
        ) else {
            throw SignalError.invalidPublicKey
        }
        
        guard let recipientSignedPrekey = try? Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: Data(base64Encoded: recipientBundle.signedPrekey)!
        ) else {
            throw SignalError.invalidPublicKey
        }
        
        // 2. Verify signed prekey signature
        let isValid = try verifySignedPrekey(
            prekeyData: Data(base64Encoded: recipientBundle.signedPrekey)!,
            signature: Data(base64Encoded: recipientBundle.signedPrekeySignature)!,
            identityKey: Data(base64Encoded: recipientBundle.identityKey)!
        )
        
        guard isValid else {
            NetworkLogger.shared.log("❌ Signed prekey signature invalid!", group: "Encryption")
            throw SignalError.invalidSignature
        }
        
        NetworkLogger.shared.log("✅ Signed prekey signature verified", group: "Encryption")
        
        // 3. Get one-time prekey (if available)
        var recipientOneTimePrekey: Curve25519.KeyAgreement.PublicKey?
        if let otkData = recipientBundle.oneTimePrekey,
           let otkKey = try? Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: Data(base64Encoded: otkData)!
           ) {
            recipientOneTimePrekey = otkKey
            NetworkLogger.shared.log("✅ Using one-time prekey", group: "Encryption")
        } else {
            NetworkLogger.shared.log("⚠️ No one-time prekey available", group: "Encryption")
        }
        
        // 4. Generate ephemeral key for this session
        let ephemeralKey = Curve25519.KeyAgreement.PrivateKey()
        
        // 5. Perform X3DH (4 DH operations)
        let dh1 = try identityKey.sharedSecretFromKeyAgreement(with: recipientSignedPrekey)
        let dh2 = try ephemeralKey.sharedSecretFromKeyAgreement(with: recipientIdentityKey)
        let dh3 = try ephemeralKey.sharedSecretFromKeyAgreement(with: recipientSignedPrekey)
        
        var sharedSecrets = [dh1, dh2, dh3]
        
        // Include one-time prekey if available
        if let otk = recipientOneTimePrekey {
            let dh4 = try ephemeralKey.sharedSecretFromKeyAgreement(with: otk)
            sharedSecrets.append(dh4)
        }
        
        // 6. Derive root key from all shared secrets
        let combinedSecret = sharedSecrets.reduce(Data()) { result, secret in
            result + secret.withUnsafeBytes { Data($0) }
        }
        
        let rootKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: combinedSecret),
            salt: Data(),
            info: Data("Signal-X3DH-RootKey".utf8),
            outputByteCount: 32
        )
        
        // 7. Initialize chain keys
        let sendingChainKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: rootKey,
            salt: Data(),
            info: Data("Signal-SendingChain".utf8),
            outputByteCount: 32
        )
        
        let receivingChainKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: rootKey,
            salt: Data(),
            info: Data("Signal-ReceivingChain".utf8),
            outputByteCount: 32
        )
        
        // 8. Create session
        let session = Session(
            rootKey: rootKey,
            sendingChainKey: sendingChainKey,
            receivingChainKey: receivingChainKey,
            sendingChainLength: 0,
            receivingChainLength: 0,
            previousSendingChainLength: 0,
            dhRatchetKeyPair: ephemeralKey,
            dhRatchetRemotePublicKey: recipientSignedPrekey
        )
        
        sessions[recipientBundle.userId] = session
        
        NetworkLogger.shared.log("✅ Session established with \(recipientBundle.userId.prefix(8))", group: "Encryption")
    }
    
    // MARK: - Message Encryption
    
    /// Encrypt a message for a specific user
    func encrypt(message: String, for userId: String, token: String) async throws -> EncryptedMessagePayload {
        NetworkLogger.shared.log("🔐 Encrypting message for \(userId.prefix(8))...", group: "Encryption")
        
        // Get or establish session
        if sessions[userId] == nil {
            NetworkLogger.shared.log("🤝 No session exists, fetching recipient keys...", group: "Encryption")
            let recipientBundle = try await fetchRecipientKeys(userId: userId, token: token)
            try establishSession(with: recipientBundle)
        }
        
        guard var session = sessions[userId] else {
            throw SignalError.noSession
        }
        
        // Ratchet forward (generate new message key)
        let messageKey = ratchetSendingChain(session: &session)
        sessions[userId] = session
        
        // Encrypt message
        guard let messageData = message.data(using: .utf8) else {
            throw SignalError.invalidMessage
        }
        
        let sealedBox = try AES.GCM.seal(messageData, using: messageKey)
        
        guard let ciphertext = sealedBox.combined else {
            throw SignalError.encryptionFailed
        }
        
        // Include ratchet public key for recipient
        let ratchetPublicKey = session.dhRatchetKeyPair.publicKey.rawRepresentation
        
        NetworkLogger.shared.log("✅ Message encrypted (\(ciphertext.count) bytes)", group: "Encryption")
        NetworkLogger.shared.log("   Chain length: \(session.sendingChainLength)", group: "Encryption")
        
        return EncryptedMessagePayload(
            ciphertext: ciphertext.base64EncodedString(),
            ratchetPublicKey: ratchetPublicKey.base64EncodedString(),
            chainLength: session.sendingChainLength,
            previousChainLength: session.previousSendingChainLength
        )
    }
    
    // MARK: - Message Decryption
    
    /// Decrypt a message from a specific user
    func decrypt(payload: EncryptedMessagePayload, from userId: String, token: String) async throws -> String {
        NetworkLogger.shared.log("🔓 Decrypting message from \(userId.prefix(8))...", group: "Encryption")
        
        // Get or establish session
        if sessions[userId] == nil {
            NetworkLogger.shared.log("⚠️ No session exists, cannot decrypt", group: "Encryption")
            throw SignalError.noSession
        }
        
        guard var session = sessions[userId] else {
            throw SignalError.noSession
        }
        
        // Check if we need to ratchet (new ratchet key received)
        if let newRatchetKeyData = Data(base64Encoded: payload.ratchetPublicKey),
           let newRatchetKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: newRatchetKeyData),
           newRatchetKey != session.dhRatchetRemotePublicKey {
            NetworkLogger.shared.log("🔄 Performing DH ratchet...", group: "Encryption")
            try performDHRatchet(session: &session, remotePublicKey: newRatchetKey)
        }
        
        // Ratchet receiving chain to correct position
        let messageKey = ratchetReceivingChain(session: &session, to: payload.chainLength)
        sessions[userId] = session
        
        // Decrypt message
        guard let ciphertext = Data(base64Encoded: payload.ciphertext) else {
            throw SignalError.invalidMessage
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        let decryptedData = try AES.GCM.open(sealedBox, using: messageKey)
        
        guard let message = String(data: decryptedData, encoding: .utf8) else {
            throw SignalError.decryptionFailed
        }
        
        NetworkLogger.shared.log("✅ Message decrypted (\(message.count) chars)", group: "Encryption")
        
        return message
    }
    
    // MARK: - Ratchet Functions
    
    private func ratchetSendingChain(session: inout Session) -> SymmetricKey {
        // Derive message key from chain key
        let messageKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: session.sendingChainKey,
            salt: Data(),
            info: Data("Signal-MessageKey-\(session.sendingChainLength)".utf8),
            outputByteCount: 32
        )
        
        // Update chain key
        session.sendingChainKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: session.sendingChainKey,
            salt: Data(),
            info: Data("Signal-ChainKey".utf8),
            outputByteCount: 32
        )
        
        session.sendingChainLength += 1
        
        return messageKey
    }
    
    private func ratchetReceivingChain(session: inout Session, to targetLength: Int) -> SymmetricKey {
        // Ratchet forward to target length
        while session.receivingChainLength < targetLength {
            session.receivingChainKey = HKDF<SHA256>.deriveKey(
                inputKeyMaterial: session.receivingChainKey,
                salt: Data(),
                info: Data("Signal-ChainKey".utf8),
                outputByteCount: 32
            )
            session.receivingChainLength += 1
        }
        
        // Derive message key
        let messageKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: session.receivingChainKey,
            salt: Data(),
            info: Data("Signal-MessageKey-\(session.receivingChainLength)".utf8),
            outputByteCount: 32
        )
        
        return messageKey
    }
    
    private func performDHRatchet(session: inout Session, remotePublicKey: Curve25519.KeyAgreement.PublicKey) throws {
        // Save previous chain length
        session.previousSendingChainLength = session.sendingChainLength
        
        // Perform DH with remote's new public key
        let dhOutput = try session.dhRatchetKeyPair.sharedSecretFromKeyAgreement(with: remotePublicKey)
        
        // Derive new root key and sending chain key
        let newRootKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: session.rootKey,
            salt: dhOutput.withUnsafeBytes { Data($0) },
            info: Data("Signal-RootKey-Ratchet".utf8),
            outputByteCount: 32
        )
        
        let newSendingChainKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: newRootKey,
            salt: Data(),
            info: Data("Signal-SendingChain-Ratchet".utf8),
            outputByteCount: 32
        )
        
        // Generate new DH ratchet key pair
        let newDHKeyPair = Curve25519.KeyAgreement.PrivateKey()
        
        // Update session
        session.rootKey = newRootKey
        session.sendingChainKey = newSendingChainKey
        session.sendingChainLength = 0
        session.dhRatchetKeyPair = newDHKeyPair
        session.dhRatchetRemotePublicKey = remotePublicKey
        
        NetworkLogger.shared.log("✅ DH ratchet complete", group: "Encryption")
    }
    
    // MARK: - Helper Functions
    
    private func verifySignedPrekey(prekeyData: Data, signature: Data, identityKey: Data) throws -> Bool {
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: identityKey)
        return publicKey.isValidSignature(signature, for: prekeyData)
    }
    
    private func fetchRecipientKeys(userId: String, token: String) async throws -> RecipientKeyBundle {
        let response = try await APIClient.shared.getUserPublicKeys(token: token, userId: userId)
        
        return RecipientKeyBundle(
            userId: userId,
            identityKey: response.keys.identityKey,
            signedPrekey: response.keys.signedPrekey,
            signedPrekeySignature: response.keys.signedPrekeySignature,
            oneTimePrekey: response.keys.oneTimePrekey
        )
    }
    
    private func saveKeysToKeychain() throws {
        guard let identityKey = identityKeyPair else {
            throw SignalError.noIdentityKey
        }
        
        // Save identity key
        try keychainHelper.save(identityKey.rawRepresentation, forKey: "signal.identityKey")
        
        // Save signed prekey
        if let signedPrekey = signedPrekeyPair {
            try keychainHelper.save(signedPrekey.rawRepresentation, forKey: "signal.signedPrekey")
        }
        
        // Save signature
        if let signature = signedPrekeySignature {
            try keychainHelper.save(signature, forKey: "signal.signature")
        }
        
        // Save one-time prekeys
        let prekeyDict = oneTimePrekeyPairs.mapValues { $0.rawRepresentation }
        if let prekeyData = try? JSONEncoder().encode(prekeyDict) {
            try keychainHelper.save(prekeyData, forKey: "signal.oneTimePrekeys")
        }
        
        NetworkLogger.shared.log("✅ Keys saved to Keychain", group: "Encryption")
    }
}

// MARK: - Data Models

struct PublicKeyBundle: Codable {
    let identityKey: String // Base64
    let signedPrekey: String // Base64
    let signedPrekeySignature: String // Base64
    let oneTimePrekeys: [OneTimePrekey]
}

struct OneTimePrekey: Codable {
    let id: String
    let publicKey: String // Base64
}

struct RecipientKeyBundle {
    let userId: String
    let identityKey: String
    let signedPrekey: String
    let signedPrekeySignature: String
    let oneTimePrekey: String?
}

struct EncryptedMessagePayload: Codable {
    let ciphertext: String // Base64
    let ratchetPublicKey: String // Base64
    let chainLength: Int
    let previousChainLength: Int
}

// MARK: - Errors

enum SignalError: LocalizedError {
    case noIdentityKey
    case invalidPublicKey
    case invalidSignature
    case noSession
    case invalidMessage
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .noIdentityKey: return "No identity key found"
        case .invalidPublicKey: return "Invalid public key format"
        case .invalidSignature: return "Signature verification failed"
        case .noSession: return "No active session with this user"
        case .invalidMessage: return "Invalid message format"
        case .encryptionFailed: return "Failed to encrypt message"
        case .decryptionFailed: return "Failed to decrypt message"
        }
    }
}
