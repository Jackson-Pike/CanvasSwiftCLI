import Foundation

public struct PlannerSubmissionSummary: Sendable, Codable, Equatable {
    public let submitted: Bool?
    public let excused: Bool?
    public let graded: Bool?
    public let missing: Bool?
    public let late: Bool?
    public let hasFeedback: Bool?

    public init(
        submitted: Bool? = nil,
        excused: Bool? = nil,
        graded: Bool? = nil,
        missing: Bool? = nil,
        late: Bool? = nil,
        hasFeedback: Bool? = nil
    ) {
        self.submitted = submitted
        self.excused = excused
        self.graded = graded
        self.missing = missing
        self.late = late
        self.hasFeedback = hasFeedback
    }
}

public struct PlannerOverride: Sendable, Codable, Equatable {
    public let id: Int
    public let markedComplete: Bool?

    public init(id: Int, markedComplete: Bool? = nil) {
        self.id = id
        self.markedComplete = markedComplete
    }
}

public struct PlannerItem: Sendable, Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let courseId: Int?
    public let plannableId: Int
    public let plannableType: String
    public let plannableDate: Date?
    public let htmlUrl: String?
    public let submissions: PlannerSubmissionSummary?
    public let plannerOverride: PlannerOverride?

    public init(
        id: String,
        title: String,
        courseId: Int?,
        plannableId: Int,
        plannableType: String,
        plannableDate: Date?,
        htmlUrl: String?,
        submissions: PlannerSubmissionSummary? = nil,
        plannerOverride: PlannerOverride? = nil
    ) {
        self.id = id
        self.title = title
        self.courseId = courseId
        self.plannableId = plannableId
        self.plannableType = plannableType
        self.plannableDate = plannableDate
        self.htmlUrl = htmlUrl
        self.submissions = submissions
        self.plannerOverride = plannerOverride
    }
}
