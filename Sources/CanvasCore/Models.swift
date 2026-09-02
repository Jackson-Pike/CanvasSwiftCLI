import Foundation

public struct GradingSchemeEntry: Codable {
    public let name: String
    public let value: Double  // 0.0–1.0 lower-bound fraction

    // Canvas encodes these as ["A", 0.94] arrays, not {"name":…,"value":…} objects
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        name  = try container.decode(String.self)
        value = try container.decode(Double.self)
    }
}

public struct Course: Codable {
    public let id: Int
    public let name: String
    public let courseCode: String
    public let applyAssignmentGroupWeights: Bool?
    public let gradingScheme: [GradingSchemeEntry]?
    public let syllabusBody: String?

    public init(id: Int, name: String, courseCode: String, applyAssignmentGroupWeights: Bool?,
                gradingScheme: [GradingSchemeEntry]?, syllabusBody: String? = nil) {
        self.id = id
        self.name = name
        self.courseCode = courseCode
        self.applyAssignmentGroupWeights = applyAssignmentGroupWeights
        self.gradingScheme = gradingScheme
        self.syllabusBody = syllabusBody
    }
}

public struct Enrollment: Codable {
    public let grades: Grades?
}

public struct Grades: Codable {
    public let currentScore: Double?
    public let currentGrade: String?
}

public struct AssignmentGroupRules: Codable {
    public let dropLowest: Int?
    public let dropHighest: Int?
    public let neverDrop: [Int]?
}

public struct AssignmentGroup: Codable {
    public let id: Int
    public let name: String
    public let groupWeight: Double
    public let rules: AssignmentGroupRules?
    public let assignments: [Assignment]
}

public struct Assignment: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, pointsPossible, dueAt, assignmentGroupId
        case descriptionHTML = "description"
        case submissionTypes, unlockAt, lockAt
        case htmlURL = "htmlUrl"   // .convertFromSnakeCase turns "html_url" -> "htmlUrl"
        case rubric
    }

    public let id: Int
    public let name: String
    public let pointsPossible: Double?  // null for ungraded surveys / not-graded types
    public let dueAt: String?
    public let assignmentGroupId: Int
    public let descriptionHTML: String?
    public let submissionTypes: [String]?
    public let unlockAt: String?
    public let lockAt: String?
    public let htmlURL: String?
    public let rubric: [RubricCriterion]?

    public init(id: Int, name: String, pointsPossible: Double?, dueAt: String?, assignmentGroupId: Int,
                descriptionHTML: String? = nil, submissionTypes: [String]? = nil, unlockAt: String? = nil,
                lockAt: String? = nil, htmlURL: String? = nil, rubric: [RubricCriterion]? = nil) {
        self.id = id
        self.name = name
        self.pointsPossible = pointsPossible
        self.dueAt = dueAt
        self.assignmentGroupId = assignmentGroupId
        self.descriptionHTML = descriptionHTML
        self.submissionTypes = submissionTypes
        self.unlockAt = unlockAt
        self.lockAt = lockAt
        self.htmlURL = htmlURL
        self.rubric = rubric
    }
}

public struct SubmissionComment: Codable {
    public let id: Int?
    public let authorId: Int
    public let authorName: String
    public let comment: String
    public let createdAt: String?
}

public struct Profile: Codable, Sendable {
    public let id: Int
    public let name: String
    public let primaryEmail: String?
}

public struct Submission: Codable {
    public let id: Int
    public let userId: Int
    public let assignmentId: Int
    public let score: Double?
    public let workflowState: String
    public let gradedAt: String?
    public let submittedAt: String?
    public let submissionComments: [SubmissionComment]?
    public let late: Bool?
    public let missing: Bool?
    public let excused: Bool?
    public let attempt: Int?
    public let rubricAssessment: [String: RubricAssessmentEntry]?

    public init(id: Int, userId: Int, assignmentId: Int, score: Double?, workflowState: String,
                gradedAt: String?, submittedAt: String?, submissionComments: [SubmissionComment]?,
                late: Bool? = nil, missing: Bool? = nil, excused: Bool? = nil, attempt: Int? = nil,
                rubricAssessment: [String: RubricAssessmentEntry]? = nil) {
        self.id = id
        self.userId = userId
        self.assignmentId = assignmentId
        self.score = score
        self.workflowState = workflowState
        self.gradedAt = gradedAt
        self.submittedAt = submittedAt
        self.submissionComments = submissionComments
        self.late = late
        self.missing = missing
        self.excused = excused
        self.attempt = attempt
        self.rubricAssessment = rubricAssessment
    }
}

public struct DiscussionAuthor: Codable {
    public let displayName: String?
}

public struct Announcement: Codable {
    public let id: Int
    public let title: String
    public let message: String?
    public let postedAt: String?
    public let author: DiscussionAuthor?
}

public extension Course {
    var gradingScale: [(String, Double)] {
        gradingScheme
            .map { $0.map { ($0.name, $0.value * 100) }.sorted { $0.1 > $1.1 } }
            ?? byuhDefaultScale
    }
}

public struct TeacherEnrollment: Decodable {
    public let userId: Int
}

public struct GradedItem {
    public let assignmentId: Int
    public let name: String
    public let groupId: Int
    public let pointsPossible: Double
    public var earnedPoints: Double?
    public var whatIfPoints: Double?

    public init(assignmentId: Int, name: String, groupId: Int, pointsPossible: Double, earnedPoints: Double? = nil, whatIfPoints: Double? = nil) {
        self.assignmentId = assignmentId
        self.name = name
        self.groupId = groupId
        self.pointsPossible = pointsPossible
        self.earnedPoints = earnedPoints
        self.whatIfPoints = whatIfPoints
    }
}

public enum SearchResultTarget: Sendable, Equatable {
    case course(id: Int, tab: String)
    case assignment(courseId: Int, assignmentId: Int)
    case conversation(id: Int)
    case external(url: String)
}

public struct SearchResultItem: Identifiable, Sendable, Equatable {
    public enum Category: String, Sendable, CaseIterable {
        case course = "Course"
        case assignment = "Assignment"
        case announcement = "Announcement"
        case discussion = "Discussion"
        case file = "File"
        case moduleItem = "Module Item"
    }

    public let id: String
    public let title: String
    public let subtitle: String?
    public let category: Category
    public let target: SearchResultTarget?

    public init(id: String, title: String, subtitle: String? = nil, category: Category, target: SearchResultTarget? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.target = target
    }
}

