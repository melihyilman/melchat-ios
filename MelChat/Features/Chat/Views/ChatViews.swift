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

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.chats.isEmpty && !viewModel.isLoading {
                    // Empty State
                    emptyStateView
                } else {
                    // Chat List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredChats) { chat in
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
                if viewModel.isLoading && viewModel.chats.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private var filteredChats: [ChatInfo] {
        if searchText.isEmpty {
            return viewModel.chats
        }
        return viewModel.chats.filter { chat in
            chat.username.localizedCaseInsensitiveContains(searchText) ||
            (chat.displayName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "message.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue.gradient)
            }

            VStack(spacing: 8) {
                Text("No Chats Yet")
                    .font(.title2.bold())

                Text("Start a conversation with someone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showNewChat = true
            } label: {
                Label("New Chat", systemImage: "plus.message.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
            }
        }
        .padding()
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
    @State private var messageText = ""
    @State private var isTyping = false // TODO: Connect to backend typing events
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
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isMessageFocused = false
                    HapticManager.shared.light()
                }
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    // Auto-scroll to latest message
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.systemGray6))
                )

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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
                            .fill(message.isFromCurrentUser ? Color.blue.gradient : Color(.systemGray5).gradient)
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
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack {
                Text("Coming Soon")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("Search for users by username")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
