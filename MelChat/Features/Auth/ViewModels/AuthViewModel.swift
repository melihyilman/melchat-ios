import Foundation
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

            // If new user, generate and upload encryption keys
            if response.user.isNewUser {
                let keyPair = encryptionService.generateKeyPair()

                // Save keys to Keychain
                try keychainHelper.save(keyPair.privateKey, forKey: KeychainHelper.Keys.privateKey)
                try keychainHelper.save(keyPair.publicKey, forKey: KeychainHelper.Keys.publicKey)

                // Upload public key to backend
                try await APIClient.shared.uploadKeys(
                    token: response.token,
                    identityKey: keyPair.publicKey.base64EncodedString(),
                    signedPrekey: keyPair.publicKey.base64EncodedString(),
                    signedPrekeySignature: keyPair.publicKey.base64EncodedString()
                )
            }

            // Save token
            try keychainHelper.save(response.token.data(using: .utf8)!, forKey: KeychainHelper.Keys.authToken)
            
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
