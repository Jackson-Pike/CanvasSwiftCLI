import Foundation
import SwiftData

@Model
public final class CachedFolder {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var parentFolderId: Int?
    public var name: String
    public var fullName: String?
    public var removedAt: Date?

    public init(id: Int, courseId: Int, parentFolderId: Int? = nil, name: String, fullName: String? = nil, removedAt: Date? = nil) {
        self.id = id
        self.courseId = courseId
        self.parentFolderId = parentFolderId
        self.name = name
        self.fullName = fullName
        self.removedAt = removedAt
    }
}

@Model
public final class CachedFile {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var folderId: Int?
    public var displayName: String
    public var contentType: String?
    public var size: Int64
    public var url: String?
    public var updatedAt: Date?
    public var localPath: String?
    public var removedAt: Date?

    public init(
        id: Int,
        courseId: Int,
        folderId: Int? = nil,
        displayName: String,
        contentType: String? = nil,
        size: Int64 = 0,
        url: String? = nil,
        updatedAt: Date? = nil,
        localPath: String? = nil,
        removedAt: Date? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.folderId = folderId
        self.displayName = displayName
        self.contentType = contentType
        self.size = size
        self.url = url
        self.updatedAt = updatedAt
        self.localPath = localPath
        self.removedAt = removedAt
    }
}
