import Foundation
import SwiftUI
import Combine

@MainActor
class NewChatViewModel: ObservableObject {
    @Published var searchResults: [UserSearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    func searchUsers(query: String) async {
        guard !query.isEmpty else {
            clearResults()
            return
        }
        
        guard let token = getToken() else {
            errorMessage = "Not authenticated - Please login first"
            NetworkLogger.shared.log("⚠️ No auth token found in Keychain")
            return
        }
        
        NetworkLogger.shared.log("✅ Using auth token: \(token.prefix(20))...")
        
        isSearching = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.searchUsers(token: token, query: query)
            searchResults = response.users
            
            NetworkLogger.shared.log("✅ Found \(searchResults.count) users")
            
            if searchResults.isEmpty {
                errorMessage = nil // Show "no results" UI instead
            }
        } catch {
            errorMessage = "Failed to search: \(error.localizedDescription)"
            NetworkLogger.shared.log("❌ Search error: \(error)")
        }
        
        isSearching = false
    }
    
    func clearResults() {
        searchResults = []
        errorMessage = nil
    }
    
    // MARK: - Helpers
    
    private func getToken() -> String? {
        let keychainHelper = KeychainHelper()
        guard let tokenData = try? keychainHelper.load(forKey: KeychainHelper.Keys.authToken),
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        return token
    }
}

