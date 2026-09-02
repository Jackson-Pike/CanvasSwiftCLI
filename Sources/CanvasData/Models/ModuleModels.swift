import Foundation
import SwiftData

@Model
public final class CachedModule {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var name: String
    public var position: Int
    public var state: String?
    public var unlockAt: Date?
    public var removedAt: Date?

    public init(id: Int, courseId: Int, name: String, position: Int, state: String? = nil, unlockAt: Date? = nil, removedAt: Date? = nil) {
        self.id = id
        self.courseId = courseId
        self.name = name
        self.position = position
        self.state = state
        self.unlockAt = unlockAt
        self.removedAt = removedAt
    }
}

@Model
public final class CachedModuleItem {
    @Attribute(.unique) public var id: Int
    public var moduleId: Int
    public var courseId: Int
    public var title: String
    public var position: Int
    public var itemType: String
    public var indent: Int
    public var contentId: Int?
    public var htmlURL: String?
    public var url: String?
    public var pageUrl: String?
    public var externalUrl: String?
    public var completionRequirementType: String?
    public var completionRequirementCompleted: Bool?
    public var removedAt: Date?

    public init(
        id: Int,
        moduleId: Int,
        courseId: Int,
        title: String,
        position: Int,
        itemType: String,
        indent: Int,
        contentId: Int? = nil,
        htmlURL: String? = nil,
        url: String? = nil,
        pageUrl: String? = nil,
        externalUrl: String? = nil,
        completionRequirementType: String? = nil,
        completionRequirementCompleted: Bool? = nil,
        removedAt: Date? = nil
    ) {
        self.id = id
        self.moduleId = moduleId
        self.courseId = courseId
        self.title = title
        self.position = position
        self.itemType = itemType
        self.indent = indent
        self.contentId = contentId
        self.htmlURL = htmlURL
        self.url = url
        self.pageUrl = pageUrl
        self.externalUrl = externalUrl
        self.completionRequirementType = completionRequirementType
        self.completionRequirementCompleted = completionRequirementCompleted
        self.removedAt = removedAt
    }
}
