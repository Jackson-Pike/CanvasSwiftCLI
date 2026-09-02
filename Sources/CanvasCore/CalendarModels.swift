import Foundation

public struct CalendarEvent: Sendable, Codable, Identifiable, Equatable {
    public let id: Int
    public let title: String
    public let contextCode: String?
    public let startAt: Date?
    public let endAt: Date?
    public let locationName: String?
    public let description: String?
    public let htmlUrl: String?

    public var courseId: Int? {
        guard let code = contextCode, code.hasPrefix("course_") else { return nil }
        return Int(code.dropFirst(7))
    }

    public init(
        id: Int,
        title: String,
        contextCode: String?,
        startAt: Date?,
        endAt: Date?,
        locationName: String?,
        description: String?,
        htmlUrl: String?
    ) {
        self.id = id
        self.title = title
        self.contextCode = contextCode
        self.startAt = startAt
        self.endAt = endAt
        self.locationName = locationName
        self.description = description
        self.htmlUrl = htmlUrl
    }
}
