import Foundation

public struct DiscussionTopic: Codable, Sendable, Equatable {
    public let id: Int
    public let title: String
    public let message: String?
    public let postedAt: String?
    public let discussionSubentryCount: Int?
    public let htmlUrl: String?
    public init(id: Int, title: String, message: String?, postedAt: String?,
                discussionSubentryCount: Int?, htmlUrl: String?) {
        self.id = id; self.title = title; self.message = message; self.postedAt = postedAt
        self.discussionSubentryCount = discussionSubentryCount; self.htmlUrl = htmlUrl
    }
}

public struct DiscussionParticipant: Codable, Sendable, Equatable {
    public let id: Int
    public let displayName: String?
    public init(id: Int, displayName: String?) { self.id = id; self.displayName = displayName }
}

/// A node in Canvas's `/view` reply tree. A struct holding `[DiscussionEntryNode]` is legal —
/// Array provides the heap indirection the recursion needs.
public struct DiscussionEntryNode: Codable, Sendable, Equatable {
    public let id: Int
    public let userId: Int?
    public let parentId: Int?
    public let message: String?
    public let createdAt: String?
    public let replies: [DiscussionEntryNode]?
    public init(id: Int, userId: Int?, parentId: Int?, message: String?, createdAt: String?,
                replies: [DiscussionEntryNode]?) {
        self.id = id; self.userId = userId; self.parentId = parentId
        self.message = message; self.createdAt = createdAt; self.replies = replies
    }
}

public struct DiscussionView: Codable, Sendable, Equatable {
    public let view: [DiscussionEntryNode]?
    public let participants: [DiscussionParticipant]?
    public init(view: [DiscussionEntryNode]?, participants: [DiscussionParticipant]?) {
        self.view = view; self.participants = participants
    }
}

public struct FlatDiscussionEntry: Equatable, Sendable {
    public let id: Int
    public let parentId: Int?
    public let depth: Int
    public let authorName: String
    public let message: String?
    public let createdAt: String?
    public let sortIndex: Int
}

/// Pre-order depth-first flatten of the reply tree, resolving author names from participants.
public func flattenDiscussion(_ view: DiscussionView) -> [FlatDiscussionEntry] {
    let names = Dictionary(uniqueKeysWithValues: (view.participants ?? []).map { ($0.id, $0.displayName ?? "Unknown") })
    var out: [FlatDiscussionEntry] = []
    var index = 0
    func walk(_ nodes: [DiscussionEntryNode], depth: Int) {
        for node in nodes {
            out.append(FlatDiscussionEntry(
                id: node.id, parentId: node.parentId, depth: depth,
                authorName: node.userId.flatMap { names[$0] } ?? "Unknown",
                message: node.message, createdAt: node.createdAt, sortIndex: index))
            index += 1
            if let replies = node.replies, !replies.isEmpty { walk(replies, depth: depth + 1) }
        }
    }
    walk(view.view ?? [], depth: 0)
    return out
}
