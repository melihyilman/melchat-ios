import Foundation
import SwiftData

// MARK: - User
@Model
final class User {
    @Attribute(.unique) var id: UUID
    var username: String
    var displayName: String?
    var email: String?
    var avatarURLString: String?

    // Signal Protocol Public Keys
    var publicIdentityKey: String
    var publicSignedPrekey: String

    // Status
    var lastSeen: Date?
    var isOnline: Bool

    // Privacy settings
    var showOnlineStatus: Bool
    var showReadReceipts: Bool

    var avatarURL: URL? {
        get {
            guard let urlString = avatarURLString else { return nil }
            return URL(string: urlString)
        }
        set {
            avatarURLString = newValue?.absoluteString
        }
    }

    init(
        id: UUID = UUID(),
        username: String,
        displayName: String? = nil,
        email: String? = nil,
        publicIdentityKey: String,
        publicSignedPrekey: String,
        isOnline: Bool = false,
        showOnlineStatus: Bool = true,
        showReadReceipts: Bool = true
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.publicIdentityKey = publicIdentityKey
        self.publicSignedPrekey = publicSignedPrekey
        self.isOnline = isOnline
        self.showOnlineStatus = showOnlineStatus
        self.showReadReceipts = showReadReceipts
    }
}

// MARK: - Message
enum MessageStatus: String, Codable {
    case pending, sent, delivered, read, failed
}

enum MessageContentType: String, Codable {
    case text, image, video, audio, file, voiceMessage
}

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var chatId: UUID
    var senderId: UUID
    var recipientId: UUID
    var groupId: UUID?

    var content: String
    var contentType: String
    var statusRaw: String
    var retryCount: Int

    var timestamp: Date
    var sentAt: Date?
    var deliveredAt: Date?
    var readAt: Date?

    var isFromCurrentUser: Bool
    var mediaURLString: String?
    var thumbnailURLString: String?
    var duration: TimeInterval?

    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var messageContentType: MessageContentType {
        get { MessageContentType(rawValue: contentType) ?? .text }
        set { contentType = newValue.rawValue }
    }

    var mediaURL: URL? {
        get {
            guard let urlString = mediaURLString else { return nil }
            return URL(string: urlString)
        }
        set {
            mediaURLString = newValue?.absoluteString
        }
    }

    var thumbnailURL: URL? {
        get {
            guard let urlString = thumbnailURLString else { return nil }
            return URL(string: urlString)
        }
        set {
            thumbnailURLString = newValue?.absoluteString
        }
    }

    init(
        id: UUID = UUID(),
        content: String,
        senderId: UUID,
        recipientId: UUID,
        chatId: UUID,
        groupId: UUID? = nil,
        contentType: MessageContentType = .text,
        status: MessageStatus = .pending,
        isFromCurrentUser: Bool,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.recipientId = recipientId
        self.groupId = groupId
        self.content = content
        self.contentType = contentType.rawValue
        self.statusRaw = status.rawValue
        self.isFromCurrentUser = isFromCurrentUser
        self.timestamp = timestamp
        self.retryCount = 0
    }
}

// MARK: - Chat
enum ChatType: String, Codable {
    case oneToOne, group
}

@Model
final class Chat {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var otherUserId: UUID?
    var groupId: UUID?
    var lastMessageText: String?
    var lastMessageAt: Date?
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool

    var chatType: ChatType {
        get { ChatType(rawValue: typeRaw) ?? .oneToOne }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        type: ChatType,
        otherUserId: UUID? = nil,
        groupId: UUID? = nil,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.otherUserId = otherUserId
        self.groupId = groupId
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
    }
}

// MARK: - Group
@Model
final class Group {
    @Attribute(.unique) var id: UUID
    var name: String
    var avatarURLString: String?
    var memberIds: String // Comma-separated UUIDs
    var adminIds: String // Comma-separated UUIDs
    var createdBy: UUID
    var createdAt: Date

    var avatarURL: URL? {
        get {
            guard let urlString = avatarURLString else { return nil }
            return URL(string: urlString)
        }
        set {
            avatarURLString = newValue?.absoluteString
        }
    }

    var members: [UUID] {
        get {
            memberIds.split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
        }
        set {
            memberIds = newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }

    var admins: [UUID] {
        get {
            adminIds.split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
        }
        set {
            adminIds = newValue.map { $0.uuidString }.joined(separator: ",")
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        members: [UUID] = [],
        admins: [UUID] = [],
        createdBy: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.memberIds = members.map { $0.uuidString }.joined(separator: ",")
        self.adminIds = admins.map { $0.uuidString }.joined(separator: ",")
    }
}
