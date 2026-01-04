# 🔑 401 Unauthorized - Token Debugging Guide

**Date:** December 27, 2025  
**Error:** `{"error": "Unauthorized"}` on `/messages/poll`

---

## 🔍 Problem Analysis

### Error Location:
```
📥 RESPONSE
URL: http://192.168.1.116:3000/api/messages/poll
Status: 401
Body: {"error": "Unauthorized"}
```

### Possible Causes:
1. ❌ Token expired (backend timeout)
2. ❌ Token not saved correctly in Keychain
3. ❌ Token corrupted or invalid format
4. ❌ Backend expecting different token format
5. ❌ Token cleared after app restart

---

## 🔧 Quick Fixes

### Fix 1: Check Token in Keychain

Add this debug code to `ChatListViewModel.swift`:

```swift
func startPolling() {
    guard let token = getToken() else {
        NetworkLogger.shared.log("❌ No token found in Keychain!", group: "Auth")
        return
    }
    
    // ⭐️ DEBUG: Log token (remove in production!)
    NetworkLogger.shared.log("🔑 Token exists: \(token.prefix(20))...", group: "Auth")
    
    // ... rest of polling code
}
```

### Fix 2: Add Token Refresh Logic

If token expires, user should re-login:

```swift
// In APIClient.swift - getWithAuth
guard (200...299).contains(httpResponse.statusCode) else {
    // ⭐️ Handle 401 specifically
    if httpResponse.statusCode == 401 {
        NetworkLogger.shared.log("❌ Token expired - User needs to re-login", group: "Auth")
        
        // Post notification to logout user
        NotificationCenter.default.post(name: NSNotification.Name("TokenExpired"), object: nil)
        
        throw APIError.serverError("Session expired. Please login again.")
    }
    
    // ... rest of error handling
}
```

### Fix 3: Listen for Token Expiry in App

Add to `MelChatApp.swift` or `AppState`:

```swift
init() {
    // Listen for token expiry
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name("TokenExpired"),
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.logout()
    }
}
```

---

## 🧪 Debug Steps

### Step 1: Check if Token Exists

In Xcode console, look for:
```
✅ Token exists: eyJhbGciOiJIUzI1NiI...
```

If you see:
```
❌ No token found in Keychain!
```

**Solution:** User needs to login again.

---

### Step 2: Verify Token Format

Backend expects: `Bearer <token>`

Check in `getWithAuth()`:
```swift
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
```

✅ This is correct!

---

### Step 3: Test with Fresh Login

1. Force quit app
2. Reopen app
3. Login again
4. Try polling

If works → Token was expired  
If fails → Backend issue

---

### Step 4: Check Backend Token Validation

Backend should:
```typescript
// Verify JWT token
const decoded = jwt.verify(token, JWT_SECRET);

// Check expiry
if (decoded.exp < Date.now() / 1000) {
  return res.status(401).json({ error: "Token expired" });
}
```

---

## 🔐 Token Lifecycle

### 1. Login (Token Generated)
```
User logs in
    ↓
Backend generates JWT token
    ↓
Token saved to Keychain
    ↓
Token valid for X hours (backend config)
```

### 2. API Calls (Token Used)
```
Every API call
    ↓
Token read from Keychain
    ↓
Added to Authorization header: "Bearer <token>"
    ↓
Backend validates token
    ↓
✅ Valid → 200 OK
❌ Invalid/Expired → 401 Unauthorized
```

### 3. Token Expiry (User Re-login)
```
Token expires after X hours
    ↓
API returns 401
    ↓
App catches error
    ↓
Logout user
    ↓
Show login screen
    ↓
User logs in again
    ↓
New token generated
```

---

## 🎯 Immediate Actions

### Action 1: Logout & Re-login

**Manual:**
1. Close app
2. Clear app data (optional)
3. Reopen app
4. Login again
5. Try again

**Programmatic (Add to SettingsView):**
```swift
Button("Logout") {
    // Clear token
    try? KeychainHelper().delete(forKey: KeychainHelper.Keys.authToken)
    
    // Reset app state
    appState.logout()
}
```

---

### Action 2: Add Auto-Logout on 401

In `APIClient.swift`, add to ALL auth methods:

```swift
private func getWithAuth<T: Decodable>(
    endpoint: String,
    token: String
) async throws -> T {
    // ... existing code ...
    
    guard (200...299).contains(httpResponse.statusCode) else {
        // ⭐️ NEW: Handle 401 Unauthorized
        if httpResponse.statusCode == 401 {
            NetworkLogger.shared.log("❌ 401 Unauthorized - Token invalid/expired", group: "Auth")
            
            // Clear token
            let keychainHelper = KeychainHelper()
            try? await MainActor.run {
                try? keychainHelper.delete(forKey: KeychainHelper.Keys.authToken)
            }
            
            throw APIError.unauthorized
        }
        
        // ... rest of error handling
    }
    
    return try JSONDecoder().decode(T.self, from: data)
}
```

Add new error case:
```swift
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    case unauthorized  // ⭐️ NEW
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please login again."
        // ... rest
        }
    }
}
```

---

## 🔄 Complete Flow with Auto-Logout

```swift
// 1. User tries to poll messages
ChatListViewModel.pollMessages()
    ↓
// 2. API call with token
APIClient.pollMessages(token: token)
    ↓
// 3. Backend returns 401
{ "error": "Unauthorized" }
    ↓
// 4. APIClient catches 401
if httpResponse.statusCode == 401 {
    // Clear token
    try? keychainHelper.delete(forKey: "authToken")
    
    // Throw error
    throw APIError.unauthorized
}
    ↓
// 5. Error propagates to ViewModel
catch APIError.unauthorized {
    // Show alert
    errorMessage = "Session expired. Please login again."
    
    // Logout user
    appState.logout()
}
    ↓
// 6. User sees login screen
AuthViews.LoginView()
```

---

## 📝 Quick Fix Implementation

### 1. Update APIError:

```swift
// In APIClient.swift
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    case unauthorized  // ⭐️ NEW
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Your session has expired. Please login again."
        }
    }
}
```

### 2. Update getWithAuth:

```swift
guard (200...299).contains(httpResponse.statusCode) else {
    // Handle 401 specifically
    if httpResponse.statusCode == 401 {
        NetworkLogger.shared.log("❌ 401 Unauthorized - Clearing token", group: "Auth")
        throw APIError.unauthorized
    }
    
    // ... rest of error handling
}
```

### 3. Catch in ViewModel:

```swift
// In ChatListViewModel.swift
do {
    let response = try await APIClient.shared.pollMessages(token: token)
    // ... handle response
} catch APIError.unauthorized {
    NetworkLogger.shared.log("❌ Session expired - logging out", group: "Auth")
    
    // Clear token
    try? KeychainHelper().delete(forKey: KeychainHelper.Keys.authToken)
    
    // Show error
    await MainActor.run {
        errorMessage = "Session expired. Please login again."
    }
    
    // Stop polling
    stopPolling()
    
} catch {
    // ... other errors
}
```

---

## ✅ Expected Behavior After Fix

### Scenario 1: Valid Token
```
User opens app
    ↓
Token exists in Keychain
    ↓
Polling starts
    ↓
✅ Messages received
```

### Scenario 2: Expired Token
```
User opens app
    ↓
Token exists but expired
    ↓
First API call returns 401
    ↓
Token cleared from Keychain
    ↓
User logged out automatically
    ↓
Login screen shown
    ↓
User logs in
    ↓
New token saved
    ↓
✅ Polling works again
```

---

## 🎯 Immediate Solution

**Right now, do this:**

1. **Force Quit App**
2. **Clear App Data** (optional: Settings → MelChat → Clear Data)
3. **Reopen App**
4. **Login Again**
5. **Try Chatting**

If 401 happens again:
- Backend token might have very short expiry (check backend JWT_EXPIRY)
- Or backend session validation is broken

---

## 🔍 Backend Check

Ask backend team:

1. **What's JWT token expiry time?**
   ```typescript
   // In backend
   const token = jwt.sign(payload, JWT_SECRET, {
       expiresIn: '7d' // ← Should be reasonable (7 days, 30 days)
   });
   ```

2. **Is token validation working?**
   ```typescript
   // In backend auth middleware
   const decoded = jwt.verify(token, JWT_SECRET);
   console.log('Token valid:', decoded);
   ```

3. **Are there any CORS issues?**
   - Check if Authorization header is allowed

---

**READY TO FIX!** 🔧🔑

Let me know if you want me to implement the auto-logout feature! 🚀
