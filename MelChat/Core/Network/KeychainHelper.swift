import Foundation
import Security

/// Simple helper for storing and retrieving data from iOS Keychain
class KeychainHelper {
    
    // MARK: - Keys
    struct Keys {
        static let authToken = "com.melchat.authToken"
        static let privateKey = "com.melchat.privateKey"
        static let publicKey = "com.melchat.publicKey"
    }
    
    // MARK: - Save
    /// Save data to Keychain with iCloud sync support
    /// - Parameters:
    ///   - data: Data to save
    ///   - key: Keychain key
    ///   - synchronizable: If true, syncs to iCloud Keychain (survives app uninstall)
    func save(_ data: Data, forKey key: String, synchronizable: Bool = true) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // ⭐️ CRITICAL: Enable iCloud Keychain sync
        // This ensures keys survive app uninstall/reinstall
        if synchronizable {
            query[kSecAttrSynchronizable as String] = true
        }
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToSave
        }
    }
    
    // MARK: - Load
    /// Load data from Keychain (checks both local and iCloud Keychain)
    func load(forKey key: String) throws -> Data {
        // First, try to load from synchronized keychain (iCloud)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny // Check both local & iCloud
        ]
        
        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // If not found, try local-only keychain (backward compatibility)
        if status == errSecItemNotFound {
            query.removeValue(forKey: kSecAttrSynchronizable as String)
            status = SecItemCopyMatching(query as CFDictionary, &result)
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.itemNotFound
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        return data
    }
    
    // MARK: - Delete
    /// Delete item from Keychain (both local and iCloud)
    func delete(forKey key: String) throws {
        // Delete from both local and synchronized keychain
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        var status = SecItemDelete(query as CFDictionary)
        
        // Also try local-only (backward compatibility)
        if status == errSecItemNotFound {
            query.removeValue(forKey: kSecAttrSynchronizable as String)
            status = SecItemDelete(query as CFDictionary)
        }
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if iCloud Keychain is available
    func isiCloudKeychainAvailable() -> Bool {
        // Try to save a test item with synchronizable flag
        let testKey = "com.melchat.icloud.test"
        let testData = "test".data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: testKey,
            kSecValueData as String: testData,
            kSecAttrSynchronizable as String: true
        ]
        
        SecItemDelete(query as CFDictionary) // Clean up first
        let status = SecItemAdd(query as CFDictionary, nil)
        SecItemDelete(query as CFDictionary) // Clean up after test
        
        return status == errSecSuccess
    }
}

// MARK: - Errors
enum KeychainError: LocalizedError {
    case unableToSave
    case itemNotFound
    case invalidData
    case unableToDelete
    
    var errorDescription: String? {
        switch self {
        case .unableToSave:
            return "Unable to save to Keychain"
        case .itemNotFound:
            return "Item not found in Keychain"
        case .invalidData:
            return "Invalid data format"
        case .unableToDelete:
            return "Unable to delete from Keychain"
        }
    }
}
