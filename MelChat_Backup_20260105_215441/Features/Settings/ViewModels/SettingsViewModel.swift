import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var showOnlineStatus: Bool = true
    @Published var showReadReceipts: Bool = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var avatarURL: URL?

    func loadProfile() async {
        guard getToken() != nil else { 
            NetworkLogger.shared.log("⚠️ No auth token for profile load")
            return 
        }

        isLoading = true

        // TODO: Backend /users/me endpoint
        // For MVP, load from Keychain/UserDefaults
        
        // Try to get username from UserDefaults (saved during registration)
        if let savedUsername = UserDefaults.standard.string(forKey: "username") {
            username = savedUsername
        }
        
        if let savedDisplayName = UserDefaults.standard.string(forKey: "displayName") {
            displayName = savedDisplayName
        }
        
        if let savedEmail = UserDefaults.standard.string(forKey: "email") {
            email = savedEmail
        }
        
        showOnlineStatus = UserDefaults.standard.bool(forKey: "showOnlineStatus")
        showReadReceipts = UserDefaults.standard.bool(forKey: "showReadReceipts")
        
        NetworkLogger.shared.log("✅ Profile loaded from local storage")

        isLoading = false
    }

    func updateProfile() async {
        guard getToken() != nil else { return }

        isLoading = true
        errorMessage = nil

        // TODO: Backend /users/me PATCH endpoint
        // For MVP, save to UserDefaults
        
        UserDefaults.standard.set(displayName, forKey: "displayName")
        UserDefaults.standard.set(showOnlineStatus, forKey: "showOnlineStatus")
        UserDefaults.standard.set(showReadReceipts, forKey: "showReadReceipts")
        
        NetworkLogger.shared.log("✅ Profile updated locally")
        
        showSuccessMessage = true
        HapticManager.shared.success()
        
        // Hide success message after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showSuccessMessage = false
        }

        isLoading = false
    }
    
    func uploadAvatar(image: UIImage) async {
        guard getToken() != nil else { return }
        
        isLoading = true
        
        do {
            // TODO: Backend /users/me/avatar POST endpoint
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                throw SettingsError.invalidImage
            }
            
            NetworkLogger.shared.log("📸 Avatar size: \(imageData.count / 1024)KB")
            
            // TODO: Upload to backend
            // For MVP, save locally
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let avatarPath = documentsPath.appendingPathComponent("avatar.jpg")
                try imageData.write(to: avatarPath)
                avatarURL = avatarPath
                
                UserDefaults.standard.set(avatarPath.absoluteString, forKey: "avatarURL")
            }
            
            NetworkLogger.shared.log("✅ Avatar saved locally")
            HapticManager.shared.success()
            
        } catch {
            errorMessage = error.localizedDescription
            NetworkLogger.shared.log("❌ Error uploading avatar: \(error)")
            HapticManager.shared.error()
        }
        
        isLoading = false
    }

    func logout() {
        // Clear Keychain
        let keychainHelper = KeychainHelper()
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.authToken)
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.privateKey)
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.publicKey)
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "displayName")
        UserDefaults.standard.removeObject(forKey: "email")
        UserDefaults.standard.removeObject(forKey: "avatarURL")

        NetworkLogger.shared.log("🚪 User logged out")
        HapticManager.shared.medium()
    }

    private func getToken() -> String? {
        let keychainHelper = KeychainHelper()
        guard let tokenData = try? keychainHelper.load(forKey: KeychainHelper.Keys.authToken),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}

// MARK: - Errors
enum SettingsError: LocalizedError {
    case invalidImage
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process image"
        case .uploadFailed:
            return "Failed to upload avatar"
        }
    }
}

