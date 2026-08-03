import Foundation
import SwiftData

@Model
public final class CachedAnnouncement {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var title: String
    public var message: String?
    public var postedAt: Date?
    public var authorName: String?
    public var readAt: Date?
    public var removedAt: Date?

    public init(id: Int, courseId: Int, title: String, message: String?, postedAt: Date?,
               authorName: String?, readAt: Date? = nil, removedAt: Date? = nil) {
        self.id = id; self.courseId = courseId; self.title = title; self.message = message
        self.postedAt = postedAt; self.authorName = authorName; self.readAt = readAt; self.removedAt = removedAt
    }
}
