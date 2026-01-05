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
        
        isSearching = true
        errorMessage = nil
        
        do {
            let response = try await APIClient.shared.searchUsers(query: query)
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
}

