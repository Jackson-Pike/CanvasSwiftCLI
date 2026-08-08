import Foundation

public struct ConversationParticipant: Codable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public init(id: Int, name: String) { self.id = id; self.name = name }
}

public struct ConversationMessage: Codable, Sendable, Equatable {
    public let id: Int
    public let authorId: Int
    public let body: String?
    public let createdAt: String?
    public init(id: Int, authorId: Int, body: String?, createdAt: String?) {
        self.id = id; self.authorId = authorId; self.body = body; self.createdAt = createdAt
    }
}

public struct Conversation: Codable, Sendable, Equatable {
    public let id: Int
    public let subject: String?
    public let workflowState: String            // "read" | "unread" | "archived"
    public let lastMessage: String?
    public let lastMessageAt: String?
    public let messageCount: Int?
    public let contextName: String?
    public let participants: [ConversationParticipant]?
    public let messages: [ConversationMessage]? // present only on the detail fetch

    public init(id: Int, subject: String?, workflowState: String, lastMessage: String?,
                lastMessageAt: String?, messageCount: Int?, contextName: String?,
                participants: [ConversationParticipant]?, messages: [ConversationMessage]?) {
        self.id = id; self.subject = subject; self.workflowState = workflowState
        self.lastMessage = lastMessage; self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount; self.contextName = contextName
        self.participants = participants; self.messages = messages
    }
}

public enum ConversationScope: String, Sendable, CaseIterable {
    case inbox, unread, archived
}
