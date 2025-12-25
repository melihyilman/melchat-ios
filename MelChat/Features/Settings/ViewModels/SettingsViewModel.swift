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

    func loadProfile() async {
        guard let token = getToken() else { return }

        isLoading = true

        do {
            // TODO: Implement get profile endpoint
            // For now, just load from UserDefaults/Keychain
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateProfile() async {
        guard let token = getToken() else { return }

        isLoading = true
        errorMessage = nil

        do {
            // TODO: Implement update profile endpoint
            showSuccessMessage = true
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }

        isLoading = false
    }

    func logout() {
        // Clear Keychain - Use KeychainHelper
        let keychainHelper = KeychainHelper()
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.authToken)
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.privateKey)
        try? keychainHelper.delete(forKey: KeychainHelper.Keys.publicKey)

        // Haptic feedback
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
