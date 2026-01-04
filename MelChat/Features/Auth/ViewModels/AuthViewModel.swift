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
    @Published var needsUsername = false  // ⭐️ NEW: Flag to show username input

    private let keychainHelper = KeychainHelper()
    private let encryptionService = EncryptionService()
    weak var appState: AppState?

    func sendCode(email: String) async {
        isLoading = true
        error = nil
        needsUsername = false  // Reset flag
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
    
    /// Try to verify with code only (for existing users)
    /// Returns true if successful, false if username needed
    func tryVerifyWithCode(email: String, code: String) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            // Try verification without username
            let response = try await APIClient.shared.verifyCode(
                email: email,
                code: code,
                username: nil,
                displayName: nil
            )
            
            // Check if this is an existing user
            if !response.user.isNewUser {
                // ✅ Existing user - complete login
                await completeLogin(response: response, email: email)
                return true
            } else {
                // ⚠️ New user - needs username
                needsUsername = true
                isLoading = false
                return false
            }
        } catch {
            // If error, assume new user needs username
            needsUsername = true
            isLoading = false
            return false
        }
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

            await completeLogin(response: response, email: email)

        } catch let apiError as APIError {
            self.error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
    
    /// Complete the login process after successful verification
    private func completeLogin(response: VerifyResponse, email: String) async {
        // Convert String ID to UUID
        guard let userId = UUID(uuidString: response.user.id) else {
            self.error = "Invalid user ID format"
            isLoading = false
            return
        }

        // ⭐️ Get access token from response
        let finalAccessToken = response.finalAccessToken
        
        // ⭐️ IMPORTANT: Save tokens FIRST before any API calls
        if let refreshToken = response.refreshToken, let expiresIn = response.expiresIn {
            do {
                // NEW: Full token management with auto-refresh
                try TokenManager.shared.saveTokens(
                    accessToken: finalAccessToken,
                    refreshToken: refreshToken,
                    expiresIn: expiresIn
                )
                NetworkLogger.shared.log("✅ Saved access + refresh tokens (expires in \(expiresIn)s)", group: "Auth")
            } catch {
                self.error = "Failed to save tokens"
                isLoading = false
                return
            }
        } else {
            // ⚠️ FALLBACK: Backend didn't send refresh token
            NetworkLogger.shared.log("⚠️ Warning: Backend didn't send refresh token!", group: "Auth")
            do {
                try keychainHelper.save(
                    finalAccessToken.data(using: .utf8)!,
                    forKey: KeychainHelper.Keys.authToken,
                    synchronizable: true
                )
            } catch {
                self.error = "Failed to save token"
                isLoading = false
                return
            }
        }

        // If new user, generate and upload encryption key
        if response.user.isNewUser {
            NetworkLogger.shared.log("🔑 New user - generating encryption key...", group: "Encryption")
            
            do {
                // ⭐️ SIMPLE E2E - Generate single Curve25519 key pair
                let publicKey = SimpleEncryption.shared.generateKeys()
                
                // Upload to backend
                try await APIClient.shared.uploadPublicKey(publicKey: publicKey)
                
                NetworkLogger.shared.log("✅ Public key uploaded", group: "Encryption")
            } catch {
                NetworkLogger.shared.log("❌ Failed to setup encryption: \(error)", group: "Encryption")
                self.error = "Failed to setup encryption"
                isLoading = false
                return
            }
        } else {
            // Load existing keys
            NetworkLogger.shared.log("✅ Existing user - loading keys", group: "Encryption")
            SimpleEncryption.shared.loadKeys()
        }
        
        // Save user info to UserDefaults for Settings
        UserDefaults.standard.set(response.user.username, forKey: "username")
        UserDefaults.standard.set(response.user.displayName, forKey: "displayName")
        UserDefaults.standard.set(email, forKey: "email")

        // Login with UUID (token already saved in TokenManager)
        appState?.login(userId: userId)

        NetworkLogger.shared.log("✅ Authentication successful - User: \(response.user.username)", group: "Auth")
    }
}
