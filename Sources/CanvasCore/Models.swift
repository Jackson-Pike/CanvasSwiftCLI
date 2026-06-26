import Foundation

public struct Course: Codable {
    public let id: Int
    public let name: String
    public let courseCode: String
    public let applyAssignmentGroupWeights: Bool
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
    public let id: Int
    public let name: String
    public let pointsPossible: Double
    public let dueAt: String?
    public let assignmentGroupId: Int
}

public struct Submission: Codable {
    public let assignmentId: Int
    public let score: Double?
    public let workflowState: String
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
