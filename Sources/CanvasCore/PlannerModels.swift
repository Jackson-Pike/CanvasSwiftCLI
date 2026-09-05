import Foundation

public struct PlannerSubmissionSummary: Sendable, Codable, Equatable {
    public let submitted: Bool?
    public let excused: Bool?
    public let graded: Bool?
    public let missing: Bool?
    public let late: Bool?
    public let hasFeedback: Bool?

    enum CodingKeys: String, CodingKey {
        case submitted
        case excused
        case graded
        case missing
        case late
        case hasFeedback
    }

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

    public init(from decoder: Decoder) throws {
        if let singleContainer = try? decoder.singleValueContainer(),
           let boolVal = try? singleContainer.decode(Bool.self) {
            self.submitted = boolVal
            self.excused = nil
            self.graded = nil
            self.missing = nil
            self.late = nil
            self.hasFeedback = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.submitted = try? container.decodeIfPresent(Bool.self, forKey: .submitted)
        self.excused = try? container.decodeIfPresent(Bool.self, forKey: .excused)
        self.graded = try? container.decodeIfPresent(Bool.self, forKey: .graded)
        self.missing = try? container.decodeIfPresent(Bool.self, forKey: .missing)
        self.late = try? container.decodeIfPresent(Bool.self, forKey: .late)
        self.hasFeedback = try? container.decodeIfPresent(Bool.self, forKey: .hasFeedback)
    }
}

public struct PlannerOverride: Sendable, Codable, Equatable {
    public let id: Int
    public let markedComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case markedComplete
    }

    public init(id: Int, markedComplete: Bool? = nil) {
        self.id = id
        self.markedComplete = markedComplete
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(Int.self, forKey: .id)) ?? 0
        self.markedComplete = try? container.decodeIfPresent(Bool.self, forKey: .markedComplete)
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

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case courseId
        case plannableId
        case plannableType
        case plannableDate
        case htmlUrl
        case submissions
        case plannerOverride
        case plannable
        case contextType
    }

    private struct NestedPlannable: Codable {
        let id: Int?
        let title: String?
        let name: String?
        let dueAt: Date?
        let startAt: Date?
        let todoDate: Date?
        let htmlUrl: String?
        let courseId: Int?
    }

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let nestedPlannable = try? container.decodeIfPresent(NestedPlannable.self, forKey: .plannable)

        let pId = (try? container.decodeIfPresent(Int.self, forKey: .plannableId))
            ?? nestedPlannable?.id
            ?? 0
        self.plannableId = pId

        let pType = (try? container.decodeIfPresent(String.self, forKey: .plannableType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .contextType))
            ?? "planner_item"
        self.plannableType = pType

        if let explicitId = try? container.decodeIfPresent(String.self, forKey: .id) {
            self.id = explicitId
        } else if let intId = try? container.decodeIfPresent(Int.self, forKey: .id) {
            self.id = "\(pType)_\(intId)"
        } else {
            self.id = "\(pType)_\(pId)"
        }

        let explicitTitle = try? container.decodeIfPresent(String.self, forKey: .title)
        self.title = explicitTitle ?? nestedPlannable?.title ?? nestedPlannable?.name ?? "Untitled"

        let cId = (try? container.decodeIfPresent(Int.self, forKey: .courseId)) ?? nestedPlannable?.courseId
        self.courseId = cId

        let pDate = (try? container.decodeIfPresent(Date.self, forKey: .plannableDate))
            ?? nestedPlannable?.dueAt
            ?? nestedPlannable?.startAt
            ?? nestedPlannable?.todoDate
        self.plannableDate = pDate

        let hUrl = (try? container.decodeIfPresent(String.self, forKey: .htmlUrl)) ?? nestedPlannable?.htmlUrl
        self.htmlUrl = hUrl

        self.submissions = try? container.decodeIfPresent(PlannerSubmissionSummary.self, forKey: .submissions)
        self.plannerOverride = try? container.decodeIfPresent(PlannerOverride.self, forKey: .plannerOverride)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(courseId, forKey: .courseId)
        try container.encode(plannableId, forKey: .plannableId)
        try container.encode(plannableType, forKey: .plannableType)
        try container.encodeIfPresent(plannableDate, forKey: .plannableDate)
        try container.encodeIfPresent(htmlUrl, forKey: .htmlUrl)
        try container.encodeIfPresent(submissions, forKey: .submissions)
        try container.encodeIfPresent(plannerOverride, forKey: .plannerOverride)
    }
}
