import Foundation
import SwiftData
import CanvasCore

@Model
public final class CachedConversation {
    @Attribute(.unique) public var id: Int
    public var subject: String?
    public var lastMessageAt: Date?
    public var lastMessageSnippet: String?
    public var workflowState: String            // Canvas is authoritative: "read"|"unread"|"archived"
    public var participantsJSON: Data?          // [ConversationParticipant] JSON blob
    public var contextName: String?
    public var messageCount: Int
    public var removedAt: Date?

    public init(id: Int, subject: String?, lastMessageAt: Date?, lastMessageSnippet: String?,
                workflowState: String, participantsJSON: Data?, contextName: String?,
                messageCount: Int, removedAt: Date? = nil) {
        self.id = id; self.subject = subject; self.lastMessageAt = lastMessageAt
        self.lastMessageSnippet = lastMessageSnippet; self.workflowState = workflowState
        self.participantsJSON = participantsJSON; self.contextName = contextName
        self.messageCount = messageCount; self.removedAt = removedAt
    }

    public var participants: [ConversationParticipant] {
        participantsJSON.flatMap { try? JSONDecoder().decode([ConversationParticipant].self, from: $0) } ?? []
    }
}

@Model
public final class CachedMessage {
    @Attribute(.unique) public var id: Int
    public var conversationId: Int
    public var authorId: Int
    public var authorName: String?
    public var body: String?
    public var createdAt: Date?
    /// Optimistically-inserted local send, not yet reconciled with Canvas (spec §5.2).
    public var pending: Bool

    public init(id: Int, conversationId: Int, authorId: Int, authorName: String?,
                body: String?, createdAt: Date?, pending: Bool = false) {
        self.id = id; self.conversationId = conversationId; self.authorId = authorId
        self.authorName = authorName; self.body = body; self.createdAt = createdAt; self.pending = pending
    }
}
