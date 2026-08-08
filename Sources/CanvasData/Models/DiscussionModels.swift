import Foundation
import SwiftData

@Model
public final class CachedDiscussionTopic {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var title: String
    public var message: String?
    public var postedAt: Date?
    public var replyCount: Int
    public var htmlURL: String?
    public var removedAt: Date?

    public init(id: Int, courseId: Int, title: String, message: String?, postedAt: Date?,
                replyCount: Int, htmlURL: String?, removedAt: Date? = nil) {
        self.id = id; self.courseId = courseId; self.title = title; self.message = message
        self.postedAt = postedAt; self.replyCount = replyCount; self.htmlURL = htmlURL; self.removedAt = removedAt
    }
}

@Model
public final class CachedDiscussionEntry {
    @Attribute(.unique) public var id: Int
    public var topicId: Int
    public var parentId: Int?
    public var depth: Int
    public var sortIndex: Int
    public var authorName: String?
    public var message: String?
    public var createdAt: Date?

    public init(id: Int, topicId: Int, parentId: Int?, depth: Int, sortIndex: Int,
                authorName: String?, message: String?, createdAt: Date?) {
        self.id = id; self.topicId = topicId; self.parentId = parentId; self.depth = depth
        self.sortIndex = sortIndex; self.authorName = authorName; self.message = message; self.createdAt = createdAt
    }
}
