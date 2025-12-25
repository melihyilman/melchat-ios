import Foundation
import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var showVerification = false
    @Published var email = ""
    @Published var verificationCode = ""
    @Published var username = ""

    private let keychainHelper = KeychainHelper()
    private let encryptionService = EncryptionService()
    weak var appState: AppState?

    func sendCode(email: String) async {
        isLoading = true
        error = nil
        self.email = email

        do {
            let response = try await APIClient.shared.sendVerificationCode(email: email)
            print("✅ \(response.message)")
            showVerification = true
        } catch let apiError as APIError {
            self.error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func verify(email: String, code: String, username: String? = nil) async {
        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.verifyCode(
                email: email,
                code: code,
                username: username,
                displayName: username
            )

            // Convert String ID to UUID
            guard let userId = UUID(uuidString: response.user.id) else {
                self.error = "Invalid user ID format"
                isLoading = false
                return
            }

            // Generate and upload encryption keys for E2E encryption
            if response.user.isNewUser {
                NetworkLogger.shared.log("🔑 New user - generating E2E encryption keys...")
                
                // Generate Signal Protocol keys
                let identityKeyPair = encryptionService.generateKeyPair()
                let signedPrekeyPair = encryptionService.generateKeyPair()
                let signedPrekeySignature = encryptionService.sign(
                    data: signedPrekeyPair.publicKey,
                    with: identityKeyPair.privateKey
                )

                // Save to Keychain
                try keychainHelper.save(identityKeyPair.privateKey, forKey: KeychainHelper.Keys.privateKey)
                try keychainHelper.save(identityKeyPair.publicKey, forKey: KeychainHelper.Keys.publicKey)
                
                NetworkLogger.shared.log("🔑 Generated keys:")
                NetworkLogger.shared.log("  Identity Key: \(identityKeyPair.publicKey.base64EncodedString().prefix(20))...")
                NetworkLogger.shared.log("  Signed Prekey: \(signedPrekeyPair.publicKey.base64EncodedString().prefix(20))...")

                // Upload to backend
                try await APIClient.shared.uploadKeys(
                    token: response.token,
                    identityKey: identityKeyPair.publicKey.base64EncodedString(),
                    signedPrekey: signedPrekeyPair.publicKey.base64EncodedString(),
                    signedPrekeySignature: signedPrekeySignature.base64EncodedString()
                )
                
                NetworkLogger.shared.log("✅ E2E encryption keys uploaded")
            } else {
                NetworkLogger.shared.log("✅ Using existing E2E encryption keys")
            }

            // Save token
            try keychainHelper.save(response.token.data(using: .utf8)!, forKey: KeychainHelper.Keys.authToken)
            
            // Load encryption keys for E2E (new or existing user)
            do {
                try await EncryptionManager.shared.loadKeys()
                NetworkLogger.shared.log("✅ Encryption keys loaded from Keychain")
            } catch {
                NetworkLogger.shared.log("⚠️ Could not load encryption keys: \(error)")
                // Continue anyway - keys might not exist yet for old users
            }
            
            // Save user info to UserDefaults for Settings
            UserDefaults.standard.set(response.user.username, forKey: "username")
            UserDefaults.standard.set(response.user.displayName, forKey: "displayName")
            UserDefaults.standard.set(email, forKey: "email")

            // Login with UUID
            appState?.login(userId: userId, token: response.token)

            print("✅ Authentication successful - User: \(response.user.username)")
        } catch let apiError as APIError {
            self.error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
