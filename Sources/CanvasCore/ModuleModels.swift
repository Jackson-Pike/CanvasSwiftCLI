import Foundation

public struct CompletionRequirement: Sendable, Codable, Equatable {
    public let type: String?
    public let minScore: Double?
    public let completed: Bool?

    public init(type: String? = nil, minScore: Double? = nil, completed: Bool? = nil) {
        self.type = type
        self.minScore = minScore
        self.completed = completed
    }
}

public struct ModuleItem: Sendable, Codable, Identifiable, Equatable {
    public let id: Int
    public let moduleId: Int?
    public let title: String
    public let position: Int?
    public let type: String
    public let indent: Int?
    public let contentId: Int?
    public let htmlUrl: String?
    public let url: String?
    public let pageUrl: String?
    public let externalUrl: String?
    public let completionRequirement: CompletionRequirement?

    public init(
        id: Int,
        moduleId: Int? = nil,
        title: String,
        position: Int? = nil,
        type: String,
        indent: Int? = nil,
        contentId: Int? = nil,
        htmlUrl: String? = nil,
        url: String? = nil,
        pageUrl: String? = nil,
        externalUrl: String? = nil,
        completionRequirement: CompletionRequirement? = nil
    ) {
        self.id = id
        self.moduleId = moduleId
        self.title = title
        self.position = position
        self.type = type
        self.indent = indent
        self.contentId = contentId
        self.htmlUrl = htmlUrl
        self.url = url
        self.pageUrl = pageUrl
        self.externalUrl = externalUrl
        self.completionRequirement = completionRequirement
    }
}

public struct Module: Sendable, Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let position: Int?
    public let state: String?
    public let unlockAt: Date?
    public let itemsCount: Int?
    public let items: [ModuleItem]?

    public init(
        id: Int,
        name: String,
        position: Int? = nil,
        state: String? = nil,
        unlockAt: Date? = nil,
        itemsCount: Int? = nil,
        items: [ModuleItem]? = nil
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.state = state
        self.unlockAt = unlockAt
        self.itemsCount = itemsCount
        self.items = items
    }
}
