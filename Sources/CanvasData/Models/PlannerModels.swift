import Foundation
import SwiftData
import CanvasCore

@Model
public final class CachedPlannerItem {
    @Attribute(.unique) public var id: String
    public var title: String
    public var courseId: Int?
    public var plannableId: Int
    public var plannableType: String
    public var plannableDate: Date?
    public var htmlUrl: String?
    public var isSubmitted: Bool
    public var isMissing: Bool
    public var isCompleted: Bool
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        courseId: Int?,
        plannableId: Int,
        plannableType: String,
        plannableDate: Date?,
        htmlUrl: String?,
        isSubmitted: Bool = false,
        isMissing: Bool = false,
        isCompleted: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.courseId = courseId
        self.plannableId = plannableId
        self.plannableType = plannableType
        self.plannableDate = plannableDate
        self.htmlUrl = htmlUrl
        self.isSubmitted = isSubmitted
        self.isMissing = isMissing
        self.isCompleted = isCompleted
        self.updatedAt = updatedAt
    }
}

@Model
public final class CachedCalendarEvent {
    @Attribute(.unique) public var id: Int
    public var title: String
    public var contextCode: String?
    public var courseId: Int?
    public var startAt: Date?
    public var endAt: Date?
    public var locationName: String?
    public var eventDescription: String?
    public var htmlUrl: String?
    public var updatedAt: Date

    public init(
        id: Int,
        title: String,
        contextCode: String?,
        courseId: Int?,
        startAt: Date?,
        endAt: Date?,
        locationName: String?,
        eventDescription: String?,
        htmlUrl: String?,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.contextCode = contextCode
        self.courseId = courseId
        self.startAt = startAt
        self.endAt = endAt
        self.locationName = locationName
        self.eventDescription = eventDescription
        self.htmlUrl = htmlUrl
        self.updatedAt = updatedAt
    }
}
