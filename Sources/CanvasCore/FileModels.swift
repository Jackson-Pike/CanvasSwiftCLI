import Foundation

public struct CanvasFolder: Sendable, Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let fullName: String?
    public let parentFolderId: Int?
    public let contextId: Int?
    public let contextType: String?
    public let filesCount: Int?
    public let foldersCount: Int?
    public let updatedAt: Date?

    public init(
        id: Int,
        name: String,
        fullName: String? = nil,
        parentFolderId: Int? = nil,
        contextId: Int? = nil,
        contextType: String? = nil,
        filesCount: Int? = nil,
        foldersCount: Int? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.parentFolderId = parentFolderId
        self.contextId = contextId
        self.contextType = contextType
        self.filesCount = filesCount
        self.foldersCount = foldersCount
        self.updatedAt = updatedAt
    }
}

public struct CanvasFile: Sendable, Codable, Identifiable, Equatable {
    public let id: Int
    public let folderId: Int?
    public let displayName: String
    public let filename: String?
    public let contentType: String?
    public let url: String?
    public let size: Int64?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let locked: Bool?

    public init(
        id: Int,
        folderId: Int? = nil,
        displayName: String,
        filename: String? = nil,
        contentType: String? = nil,
        url: String? = nil,
        size: Int64? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        locked: Bool? = nil
    ) {
        self.id = id
        self.folderId = folderId
        self.displayName = displayName
        self.filename = filename
        self.contentType = contentType
        self.url = url
        self.size = size
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.locked = locked
    }
}
