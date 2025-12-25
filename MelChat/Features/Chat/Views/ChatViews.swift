import SwiftUI
import SwiftData

// MARK: - Chat List
struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showNewChat = false
    @State private var searchText = ""
    
    // SwiftData context
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    
    // IMPORTANT: Query SwiftData for real-time updates
    @Query(sort: \Chat.lastMessageAt, order: .reverse) private var localChats: [Chat]

    var body: some View {
        NavigationStack {
            ZStack {
                // Use local chats if available, otherwise show viewModel chats
                let displayChats = combinedChats()
                
                if displayChats.isEmpty && !viewModel.isLoading {
                    // Empty State with animation
                    EmptyChatState(onNewChatTap: {
                        showNewChat = true
                    })
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Chat List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayChats) { chat in
                                NavigationLink {
                                    ChatDetailView(chat: chat)
                                } label: {
                                    ChatRow(chat: chat)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.leading, 88)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadChats()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search chats")
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.light()
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
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
                if viewModel.isLoading && combinedChats().isEmpty {
                    ProgressView()
                }
            }
        }
    }
    
    // Combine local SwiftData chats with backend chats
    private func combinedChats() -> [ChatInfo] {
        // Convert local SwiftData chats to ChatInfo
        let localChatInfos = localChats.map { chat in
            ChatInfo(
                userId: chat.otherUserId?.uuidString ?? "",
                username: chat.otherUserName ?? "Unknown",
                displayName: chat.otherUserDisplayName,
                isOnline: false,
                lastSeen: nil,
                lastMessageAt: chat.lastMessageAt?.ISO8601Format(),
                lastMessageStatus: nil
            )
        }
        
        // Merge with backend chats (remove duplicates, prefer local)
        var merged = localChatInfos
        for backendChat in viewModel.chats {
            // Check if already in local
            let exists = localChatInfos.contains { $0.userId == backendChat.userId }
            if !exists {
                merged.append(backendChat)
            }
        }
        
        // Sort by lastMessageAt
        return merged.sorted { (chat1, chat2) -> Bool in
            guard let date1 = chat1.lastMessageAt,
                  let date2 = chat2.lastMessageAt else {
                return false
            }
            return date1 > date2
        }
    }

    private var filteredChats: [ChatInfo] {
        let chats = combinedChats()
        
        if searchText.isEmpty {
            return chats
        }
        return chats.filter { chat in
            chat.username.localizedCaseInsensitiveContains(searchText) ||
            (chat.displayName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

// MARK: - Chat Row
struct ChatRow: View {
    let chat: ChatInfo

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            AvatarView(
                name: chat.displayName ?? chat.username,
                size: 60
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.displayName ?? chat.username)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if let lastMessageAt = chat.lastMessageAt {
                        Text(formattedDate(lastMessageAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    if chat.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }

                    Text(chat.isOnline ? "Online" : "Offline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let status = chat.lastMessageStatus {
                        Image(systemName: statusIcon(status))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
    }

    private func formattedDate(_ dateString: String) -> String {
        // Parse ISO string and format
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return date.formatted(.dateTime.weekday(.abbreviated))
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "delivered": return "checkmark.circle"
        case "read": return "checkmark.circle.fill"
        case "queued": return "clock"
        default: return "checkmark"
        }
    }
}

// MARK: - Chat Detail View
struct ChatDetailView: View {
    let chat: ChatInfo
    @StateObject private var viewModel: ChatViewModel
    // @StateObject private var voiceRecorder = VoiceRecorder() // TODO: Add back when VoiceRecorder is added to Xcode
    @State private var messageText = ""
    @State private var isTyping = false // TODO: Connect to backend typing events
    @State private var showVoiceRecording = false
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
                        // Empty messages state
                        EmptyMessagesState(userName: chat.displayName ?? chat.username)
                            .transition(.scale.combined(with: .opacity))
                            .padding(.top, 100)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(message: message)
                                    .messageEnterAnimation(delay: Double(index) * 0.02)
                                    .id(message.id)
                            }

                            // Typing indicator with animation
                            if isTyping {
                                TypingIndicatorBubble()
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                    .id("typing")
                            }
                        }
                        .padding()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isMessageFocused = false
                    HapticManager.shared.light()
                }
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    // Auto-scroll to latest message with bounce
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            HStack(spacing: 12) {
                // Photo button
                Button {
                    isMessageFocused = false
                    viewModel.showImagePicker = true
                    HapticManager.shared.light()
                } label: {
                    Image(systemName: "photo.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                
                HStack(spacing: 8) {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .focused($isMessageFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            isMessageFocused ? Color.blue.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
                .animation(.spring(response: 0.3), value: isMessageFocused)

                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(messageText.isEmpty ? Color.gray.gradient : Color.blue.gradient)
                            .frame(width: 44, height: 44)

                        Image(systemName: "arrow.up")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                }
                .disabled(messageText.isEmpty || viewModel.isSending)
                .animation(.spring(response: 0.3), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .animation(.spring(response: 0.3), value: isMessageFocused)
        }
        .navigationTitle(chat.displayName ?? chat.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    // TODO: Navigate to profile view
                    HapticManager.shared.light()
                } label: {
                    HStack(spacing: 12) {
                        // Avatar
                        AvatarView(
                            name: chat.displayName ?? chat.username,
                            size: 36
                        )
                        
                        // Name & Status
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chat.displayName ?? chat.username)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 4) {
                                if chat.isOnline {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    
                                    Text("Online")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.5))
                                        .frame(width: 8, height: 8)
                                    
                                    if let lastSeen = chat.lastSeen {
                                        Text(formatLastSeen(lastSeen))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Offline")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        // TODO: Video call
                        HapticManager.shared.light()
                    } label: {
                        Label("Video Call", systemImage: "video.fill")
                    }
                    
                    Button {
                        // TODO: Voice call
                        HapticManager.shared.light()
                    } label: {
                        Label("Voice Call", systemImage: "phone.fill")
                    }
                    
                    Divider()
                    
                    Button {
                        // TODO: Search in conversation
                        HapticManager.shared.light()
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    
                    Button {
                        // TODO: View profile
                        HapticManager.shared.light()
                    } label: {
                        Label("View Profile", systemImage: "person.circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        // TODO: Block user
                        HapticManager.shared.medium()
                    } label: {
                        Label("Block User", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }

            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        isMessageFocused = false
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                }
            }
        }
        // TODO: Add back when VoiceRecorder is added to Xcode
        /*
        .fullScreenCover(isPresented: $showVoiceRecording) {
            VoiceRecordingView(
                recorder: voiceRecorder,
                isPresented: $showVoiceRecording,
                onSend: { url in
                    Task {
                        await sendVoiceMessage(url)
                    }
                }
            )
        }
        */
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
    
    // Format last seen time
    private func formatLastSeen(_ dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return "Offline"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        // Haptic feedback
        HapticManager.shared.medium()

        let text = messageText
        messageText = ""
        isMessageFocused = false

        Task {
            await viewModel.sendMessage(text)
        }
    }
    
    private func sendVoiceMessage(_ url: URL) async {
        HapticManager.shared.success()
        
        // TODO: Upload voice message and send
        // For now, just log
        NetworkLogger.shared.log("🎙️ Voice message recorded: \(url.lastPathComponent)")
        
        // In future, call viewModel.sendVoiceMessage(url)
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message content
                if message.messageContentType == .image {
                    // Image message
                    if let mediaURL = message.mediaURL {
                        AsyncImage(url: mediaURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: 250, maxHeight: 300)
                                    .clipped()
                            case .failure:
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.red.opacity(0.1))
                                        .frame(width: 200, height: 200)
                                    
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.badge.exclamationmark")
                                            .font(.largeTitle)
                                            .foregroundStyle(.red)
                                        Text("Failed to load")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                } else {
                    // Text message
                    Text(message.content)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            if message.isFromCurrentUser {
                                // Sent messages - Blue gradient
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            } else {
                                // Received messages - Adaptive background
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            }
                        }
                        .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                        .shadow(
                            color: message.isFromCurrentUser ? Color.blue.opacity(0.2) : Color.black.opacity(0.05),
                            radius: 8,
                            y: 4
                        )
                }
                
                // Timestamp & Status
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if message.isFromCurrentUser {
                        statusIcon
                    }
                }
                .padding(.horizontal, 4)
            }

            if !message.isFromCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .pending:
            Image(systemName: "clock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .delivered:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        case .read:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(.blue)
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
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = NewChatViewModel()
    @State private var searchText = ""
    @State private var selectedUser: UserSearchResult?
    @State private var navigateToChat = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    
                    TextField("Search username", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await viewModel.searchUsers(query: searchText)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            viewModel.clearResults()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Results
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("No users found")
                            .font(.headline)
                        
                        Text("Try a different username")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue.opacity(0.5))
                        
                        Text("Search for users")
                            .font(.headline)
                        
                        Text("Enter a username to find people")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    // User List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.searchResults, id: \.id) { user in
                                Button {
                                    selectedUser = user
                                    Task {
                                        await startChat(with: user)
                                    }
                                } label: {
                                    UserSearchRow(user: user)
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                    .padding(.leading, 88)
                            }
                        }
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
            .navigationDestination(isPresented: $navigateToChat) {
                if let user = selectedUser {
                    ChatDetailView(chat: ChatInfo(
                        userId: user.id,
                        username: user.username,
                        displayName: user.displayName,
                        isOnline: user.isOnline,
                        lastSeen: nil,
                        lastMessageAt: nil,
                        lastMessageStatus: nil
                    ))
                }
            }
        }
    }
    
    private func startChat(with user: UserSearchResult) async {
        HapticManager.shared.light()
        
        // Check if chat already exists in local DB
        guard let userIdUUID = UUID(uuidString: user.id) else {
            NetworkLogger.shared.log("⚠️ Invalid user ID format")
            return
        }
        
        guard let currentUserId = appState.currentUserId else {
            NetworkLogger.shared.log("⚠️ No current user ID")
            return
        }
        
        // Generate deterministic chat ID (same logic as ChatViewModel & ChatListViewModel)
        let chatId = generateChatId(userId1: currentUserId, userId2: userIdUUID)
        
        NetworkLogger.shared.log("🆔 Generated chat ID: \(chatId)", group: "Debug")
        
        let descriptor = FetchDescriptor<Chat>(
            predicate: #Predicate<Chat> { chat in
                chat.id == chatId
            }
        )
        
        if let existingChats = try? modelContext.fetch(descriptor),
           !existingChats.isEmpty {
            // Chat exists, navigate to it
            NetworkLogger.shared.log("✅ Chat already exists")
            HapticManager.shared.success()
            navigateToChat = true
            return
        }
        
        // Create new chat with deterministic ID
        let newChat = Chat(
            id: chatId,  // Use deterministic ID, not random!
            otherUserId: userIdUUID,
            otherUserName: user.username,
            otherUserDisplayName: user.displayName
        )
        
        modelContext.insert(newChat)
        try? modelContext.save()
        
        NetworkLogger.shared.log("✅ New chat created with ID: \(chatId)")
        HapticManager.shared.success()
        
        // Navigate to chat
        navigateToChat = true
    }
    
    // Generate deterministic chat ID (same as ChatViewModel & ChatListViewModel)
    private func generateChatId(userId1: UUID, userId2: UUID) -> UUID {
        let sorted = [userId1, userId2].sorted { $0.uuidString < $1.uuidString }
        let combined = sorted[0].uuidString + sorted[1].uuidString
        
        guard let data = combined.data(using: .utf8) else {
            return UUID()
        }
        
        let hashData = data.withUnsafeBytes { buffer in
            var hash = [UInt8](repeating: 0, count: 16)
            for (index, byte) in buffer.enumerated() {
                hash[index % 16] ^= byte
            }
            return Data(hash)
        }
        
        let bytes = [UInt8](hashData.prefix(16))
        let uuidString = String(format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                               bytes[0], bytes[1], bytes[2], bytes[3],
                               bytes[4], bytes[5], bytes[6], bytes[7],
                               bytes[8], bytes[9],
                               bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

// MARK: - User Search Row
struct UserSearchRow: View {
    let user: UserSearchResult
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            AvatarView(
                name: user.displayName ?? user.username,
                size: 60
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName ?? user.username)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if user.isOnline {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Online")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
    }
}

// MARK: - Previews
#Preview("Chat List") {
    ChatListView()
}

#Preview("Chat Detail") {
    NavigationStack {
        ChatDetailView(chat: ChatInfo(
            userId: "123",
            username: "testuser",
            displayName: "Test User",
            isOnline: true,
            lastSeen: nil,
            lastMessageAt: ISO8601DateFormatter().string(from: Date()),
            lastMessageStatus: "delivered"
        ))
    }
}
