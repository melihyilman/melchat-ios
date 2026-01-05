import SwiftUI
import SwiftData

// MARK: - Chat List
struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showNewChat = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()  // ⭐️ NEW: For programmatic navigation
    @State private var selectedChat: ChatInfo?  // ⭐️ NEW: For new chat
    
    // SwiftData context
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    
    // IMPORTANT: Query SwiftData for real-time updates
    @Query(sort: \Chat.lastMessageAt, order: .reverse) private var localChats: [Chat]
    
    // Computed property to merge and deduplicate chats
    private var allChats: [ChatInfo] {
        // Convert local SwiftData chats to ChatInfo
        var chatDict: [String: ChatInfo] = [:]
        
        // Add local chats first (priority)
        for chat in localChats {
            guard let userId = chat.otherUserId?.uuidString else { continue }
            
            chatDict[userId] = ChatInfo(
                userId: userId,
                username: chat.otherUserName ?? "Unknown",
                displayName: chat.otherUserDisplayName,
                isOnline: false, // Will be updated from backend
                lastSeen: nil,
                lastMessage: chat.lastMessageText,
                lastMessageAt: chat.lastMessageAt?.ISO8601Format(),
                lastMessageStatus: chat.lastMessageStatus,
                unreadCount: chat.unreadCount,
                lastMessageFromMe: chat.lastMessageFromMe
            )
        }
        
        // Merge with backend chats (don't duplicate)
        for backendChat in viewModel.chats {
            // Only add if not already in local
            if chatDict[backendChat.userId] == nil {
                chatDict[backendChat.userId] = backendChat
            }
        }
        
        // Sort by lastMessageAt
        return chatDict.values.sorted { (chat1, chat2) -> Bool in
            guard let date1 = chat1.lastMessageAt,
                  let date2 = chat2.lastMessageAt else {
                return false
            }
            return date1 > date2
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if allChats.isEmpty && !viewModel.isLoading {
                    // Empty State
                    emptyStateView
                } else {
                    // Chat List with animations
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredChats.enumerated()), id: \.element.id) { index, chat in
                                NavigationLink(value: chat) {
                                    ChatRow(chat: chat)
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: filteredChats.count)

                                if index < filteredChats.count - 1 {
                                    Divider()
                                        .padding(.leading, 90)
                                        .transition(.opacity)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .refreshable {
                        HapticManager.shared.light()
                        await viewModel.loadChats()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search chats")
            .navigationTitle("Chats")
            .navigationDestination(for: ChatInfo.self) { chat in
                ChatDetailView(chat: chat)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.light()
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartNewChat"))) { notification in
                // ⭐️ Handle new chat notification
                guard let userInfo = notification.userInfo,
                      let userId = userInfo["userId"] as? String,
                      let username = userInfo["username"] as? String,
                      let displayName = userInfo["displayName"] as? String else {
                    return
                }
                
                NetworkLogger.shared.log("📱 Received StartNewChat notification for \(username)", group: "ChatList")
                
                // Create ChatInfo and navigate
                let newChat = ChatInfo(
                    userId: userId,
                    username: username,
                    displayName: displayName,
                    isOnline: false,
                    lastSeen: nil,
                    lastMessage: nil,
                    lastMessageAt: nil,
                    lastMessageStatus: nil,
                    unreadCount: nil,
                    lastMessageFromMe: nil
                )
                
                // Navigate to chat
                navigationPath.append(newChat)
                
                HapticManager.shared.success()
            }
            .task {
                // Configure ChatListViewModel with SwiftData context
                guard let currentUserId = appState.currentUserId else {
                    NetworkLogger.shared.log("⚠️ No current user ID in AppState")
                    await viewModel.loadChats()
                    viewModel.startPolling()
                    return
                }
                
                viewModel.configure(
                    modelContext: modelContext,
                    currentUserId: currentUserId
                )
                
                await viewModel.loadChats()
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .overlay {
                if viewModel.isLoading && allChats.isEmpty {
                    VStack(spacing: 20) {
                        PikachuAnimationView(
                            size: 100,
                            showMessage: true,
                            message: "Loading chats..."
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
        }
    }

    private var filteredChats: [ChatInfo] {
        if searchText.isEmpty {
            return allChats
        }
        return allChats.filter { chat in
            chat.username.localizedCaseInsensitiveContains(searchText) ||
            (chat.displayName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // ⚡️ Pikachu Animation
            PikachuAnimationView(
                size: 120,
                showMessage: true,
                message: "No Chats Yet"
            )

            VStack(spacing: 8) {
                Text("Start a conversation with someone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                HapticManager.shared.success()
                showNewChat = true
            } label: {
                Label("New Chat", systemImage: "plus.message.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .orange.opacity(0.3), radius: 10, y: 5)
            }
        }
        .padding()
    }
}

// MARK: - Chat Row (Modern WhatsApp-like Design with Animations)
struct ChatRow: View {
    let chat: ChatInfo
    @State private var isPressing = false
    @State private var hasUnreadAnimation = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    name: chat.displayNameOrUsername,
                    size: 60
                )
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                
                // Online indicator with pulse animation
                if chat.isOnline {
                    ZStack {
                        // Pulse ring
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .scaleEffect(hasUnreadAnimation ? 1.4 : 1.0)
                            .opacity(hasUnreadAnimation ? 0 : 1)
                        
                        // Main online dot
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 2.5)
                            )
                    }
                    .onAppear {
                        withAnimation(
                            .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                        ) {
                            hasUnreadAnimation = true
                        }
                    }
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Top row: Name + Time
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(chat.displayNameOrUsername)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    // Time
                    if let time = chat.formattedLastMessageTime {
                        Text(time)
                            .font(.system(size: 13))
                            .foregroundStyle(hasUnreadCount ? .orange : .secondary)
                    }
                }

                // Bottom row: Status icon + Last message + Unread badge
                HStack(alignment: .center, spacing: 6) {
                    // Status icon (if message from me)
                    if let fromMe = chat.lastMessageFromMe, fromMe, let status = chat.lastMessageStatus {
                        statusIcon(status)
                    }
                    
                    // Last message preview
                    if let lastMessage = chat.lastMessage {
                        Text(lastMessage)
                            .font(.system(size: 15))
                            .foregroundStyle(hasUnreadCount ? .primary : .secondary)
                            .fontWeight(hasUnreadCount ? .medium : .regular)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                            .italic()
                    }

                    Spacer(minLength: 8)
                    
                    // Unread badge
                    if let unreadCount = chat.unreadCount, unreadCount > 0 {
                        UnreadBadge(count: unreadCount)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(hasUnreadCount ? Color.orange.opacity(0.05) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: hasUnreadCount)
        )
        .scaleEffect(isPressing ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressing)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressing = pressing
            if pressing {
                HapticManager.shared.light()
            }
        }, perform: {})
    }
    
    private var hasUnreadCount: Bool {
        if let count = chat.unreadCount, count > 0 {
            return true
        }
        return false
    }
    
    @ViewBuilder
    private func statusIcon(_ status: String) -> some View {
        switch status.lowercased() {
        case "sent":
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.gray)
        case "delivered":
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.gray)
        case "read":
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.orange)
        default:
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - Unread Badge Component
struct UnreadBadge: View {
    let count: Int
    @State private var isAnimating = false
    
    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, count > 9 ? 6 : 0)
            .background(
                ZStack {
                    // Pulse effect
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .scaleEffect(isAnimating ? 1.4 : 1.0)
                        .opacity(isAnimating ? 0 : 0.6)
                    
                    // Main badge
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .shadow(color: .orange.opacity(0.4), radius: 4, y: 2)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.0)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Chat Detail View
struct ChatDetailView: View {
    let chat: ChatInfo
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var isTyping = false // TODO: Connect to backend typing events
    @State private var showCelebration = false // ⚡️ Pikachu celebration
    @FocusState private var isMessageFocused: Bool
    
    // SwiftData context
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    init(chat: ChatInfo) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            otherUserId: chat.userId,
            otherUserName: chat.displayName ?? chat.username
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        // Empty state - Pikachu waiting for first message
                        VStack(spacing: 20) {
                            Spacer()
                            
                            PikachuAnimationView(
                                size: 100,
                                showMessage: true,
                                message: "Say hi! ⚡️"
                            )
                            
                            Text("Start the conversation")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                    .id(message.id)
                            }

                            // Typing indicator
                            if isTyping {
                                TypingIndicatorView()
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                    .id("typing")
                            }
                        }
                        .padding()
                        .id(viewModel.messages.count) // ⚡️ Force refresh when count changes
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isMessageFocused = false
                    HapticManager.shared.light()
                }
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    // Auto-scroll to latest message with smooth animation
                    if newValue > oldValue, let lastMessage = viewModel.messages.last {
                        // Small delay to ensure view is rendered
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onAppear {
                    // Scroll to bottom on initial load
                    if let lastMessage = viewModel.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .overlay {
                    // Loading state - Pikachu loading
                    if viewModel.isLoading && viewModel.messages.isEmpty {
                        VStack(spacing: 20) {
                            PikachuAnimationView(
                                size: 80,
                                showMessage: true,
                                message: "Loading..."
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                    }
                }
            }

            Divider()

            // Input Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .focused($isMessageFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    // Clear button (when typing)
                    if !messageText.isEmpty {
                        Button {
                            messageText = ""
                            HapticManager.shared.light()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 16))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.systemGray6))
                )
                .animation(.spring(response: 0.3), value: messageText.isEmpty)

                // Send button
                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(messageText.isEmpty ? 
                                AnyShapeStyle(Color.gray.gradient) : 
                                AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: messageText.isEmpty ? .clear : .orange.opacity(0.4),
                                radius: 8,
                                y: 2
                            )

                        Image(systemName: viewModel.isSending ? "hourglass" : "arrow.up")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(viewModel.isSending ? 180 : 0))
                            .animation(.easeInOut(duration: 0.3), value: viewModel.isSending)
                    }
                }
                .disabled(messageText.isEmpty || viewModel.isSending)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: -2)
            )
        }
        .navigationTitle(chat.displayName ?? chat.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(chat.displayName ?? chat.username)
                        .font(.headline)

                    if chat.isOnline {
                        Text("Online")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .task {
            // Configure viewModel with SwiftData context
            guard let currentUserId = appState.currentUserId else {
                NetworkLogger.shared.log("⚠️ No current user ID in AppState")
                return
            }
            
            // Generate or fetch chatId (use deterministic ID based on user IDs)
            let chatId = generateChatId(userId1: currentUserId, userId2: UUID(uuidString: chat.userId) ?? UUID())
            
            viewModel.configure(
                modelContext: modelContext,
                currentUserId: currentUserId,
                chatId: chatId
            )
            
            await viewModel.loadMessages()
            
            // Start polling for real-time updates
            viewModel.startPolling()
        }
        .onDisappear {
            // Stop polling when leaving chat
            viewModel.stopPolling()
        }
        .overlay {
            // ⚡️ Pikachu celebration overlay
            if showCelebration {
                PikachuCelebrationView {
                    showCelebration = false
                }
                .zIndex(1000)
            }
        }
    }
    
    // Generate deterministic chat ID from two user IDs
    private func generateChatId(userId1: UUID, userId2: UUID) -> UUID {
        // Sort UUIDs to ensure same chatId regardless of order
        let sorted = [userId1, userId2].sorted { $0.uuidString < $1.uuidString }
        let combined = sorted[0].uuidString + sorted[1].uuidString
        
        // Generate deterministic UUID from combined string
        var hasher = Hasher()
        hasher.combine(combined)
        let hashValue = hasher.finalize()
        
        // Convert hash to UUID-like string
        let uuidString = String(format: "%08X-%04X-%04X-%04X-%012X",
                               (hashValue >> 96) & 0xFFFFFFFF,
                               (hashValue >> 80) & 0xFFFF,
                               (hashValue >> 64) & 0xFFFF,
                               (hashValue >> 48) & 0xFFFF,
                               hashValue & 0xFFFFFFFFFFFF)
        
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        // Haptic feedback
        HapticManager.shared.medium()

        let text = messageText
        messageText = ""
        isMessageFocused = false
        
        // ⚡️ Show Pikachu celebration
        showCelebration = true

        Task {
            await viewModel.sendMessage(text)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isFromCurrentUser ? 
                                AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)) : 
                                AnyShapeStyle(Color(.systemGray5).gradient)
                            )
                    )
                    .foregroundStyle(message.isFromCurrentUser ? .white : .primary)

                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if message.isFromCurrentUser {
                        statusIcon
                    }
                }
            }

            if !message.isFromCurrentUser { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .pending:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .delivered:
            Image(systemName: "checkmark.checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .read:
            Image(systemName: "checkmark.checkmark")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}

// MARK: - New Chat View
struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar (sabit kalacak)
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search by username", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await searchUsers()
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
                
                Divider()
                
                // Results area - ZStack ile smooth geçişler
                ZStack {
                    if isSearching {
                        VStack(spacing: 20) {
                            Spacer()
                            PikachuAnimationView(
                                size: 80,
                                showMessage: true,
                                message: "Searching..."
                            )
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundStyle(.orange)
                            
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            PikachuAnimationView(
                                size: 100,
                                showMessage: true,
                                message: "No users found"
                            )
                            
                            Text("Try searching with a different username")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    } else if searchResults.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            PikachuAnimationView(
                                size: 100,
                                showMessage: true,
                                message: "Search for Users"
                            )
                            
                            Text("Enter a username to start a conversation")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults) { user in
                                    Button {
                                        startChat(with: user)
                                    } label: {
                                        UserSearchRow(user: user)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func searchUsers() async {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        do {
            NetworkLogger.shared.log("🔍 Searching users: \(searchText)", group: "NewChat")
            
            let response = try await APIClient.shared.searchUsers(query: searchText)
            
            searchResults = response.users
            
            NetworkLogger.shared.log("✅ Found \(searchResults.count) users", group: "NewChat")
            
        } catch {
            errorMessage = "Search failed. Please try again."
            NetworkLogger.shared.log("❌ Search error: \(error)", group: "NewChat")
        }
        
        isSearching = false
    }
    
    private func startChat(with user: UserSearchResult) {
        HapticManager.shared.light()
        
        NetworkLogger.shared.log("💬 Starting chat with \(user.username)", group: "NewChat")
        
        // Send notification to ChatListView to navigate
        NotificationCenter.default.post(
            name: NSNotification.Name("StartNewChat"),
            object: nil,
            userInfo: [
                "userId": user.id,
                "username": user.username,
                "displayName": user.displayName ?? user.username
            ]
        )
        
        // Dismiss sheet
        dismiss()
    }
}

// MARK: - User Search Row
struct UserSearchRow: View {
    let user: UserSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(
                name: user.displayName ?? user.username,
                size: 50
            )
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? user.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    Text("@\(user.username)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    
                    if user.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

// MARK: - Previews
#Preview("Chat List") {
    ChatListView()
}

#Preview("New Chat") {
    NewChatView()
        .environmentObject(AppState())
}

#Preview("Chat Row - With Unread") {
    VStack(spacing: 0) {
        ChatRow(chat: ChatInfo(
            userId: "1",
            username: "alice",
            displayName: "Alice Johnson",
            isOnline: true,
            lastSeen: nil,
            lastMessage: "Hey! Did you see that new feature? It's amazing! 🎉",
            lastMessageAt: ISO8601DateFormatter().string(from: Date()),
            lastMessageStatus: "read",
            unreadCount: 3,
            lastMessageFromMe: false
        ))
        Divider().padding(.leading, 72)
        
        ChatRow(chat: ChatInfo(
            userId: "2",
            username: "bob",
            displayName: "Bob Smith",
            isOnline: false,
            lastSeen: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
            lastMessage: "Sure, sounds good! See you tomorrow 👋",
            lastMessageAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
            lastMessageStatus: "delivered",
            unreadCount: 0,
            lastMessageFromMe: true
        ))
        Divider().padding(.leading, 72)
        
        ChatRow(chat: ChatInfo(
            userId: "3",
            username: "charlie",
            displayName: "Charlie Brown",
            isOnline: false,
            lastSeen: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800)),
            lastMessage: nil,
            lastMessageAt: nil,
            lastMessageStatus: nil,
            unreadCount: 0,
            lastMessageFromMe: nil
        ))
    }
}

#Preview("Chat Detail") {
    NavigationStack {
        ChatDetailView(chat: ChatInfo(
            userId: "123",
            username: "testuser",
            displayName: "Test User",
            isOnline: true,
            lastSeen: nil,
            lastMessage: "Hey! How are you doing?",
            lastMessageAt: ISO8601DateFormatter().string(from: Date()),
            lastMessageStatus: "delivered",
            unreadCount: 3,
            lastMessageFromMe: false
        ))
    }
}
