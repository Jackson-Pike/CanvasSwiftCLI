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

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case contextCode
        case startAt
        case endAt
        case locationName
        case description
        case htmlUrl
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            self.id = idInt
        } else if let idStr = try? container.decode(String.self, forKey: .id), let intVal = Int(idStr) {
            self.id = intVal
        } else {
            self.id = 0
        }
        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Untitled Event"
        self.contextCode = try? container.decodeIfPresent(String.self, forKey: .contextCode)
        self.startAt = try? container.decodeIfPresent(Date.self, forKey: .startAt)
        self.endAt = try? container.decodeIfPresent(Date.self, forKey: .endAt)
        self.locationName = try? container.decodeIfPresent(String.self, forKey: .locationName)
        self.description = try? container.decodeIfPresent(String.self, forKey: .description)
        self.htmlUrl = try? container.decodeIfPresent(String.self, forKey: .htmlUrl)
    }
}
