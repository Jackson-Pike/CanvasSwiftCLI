import Foundation

struct Course: Codable {
    let id: Int
    let name: String
    let courseCode: String
    let applyAssignmentGroupWeights: Bool
}

struct Enrollment: Codable {
    let grades: Grades?
}

struct Grades: Codable {
    let currentScore: Double?
    let currentGrade: String?
}

struct AssignmentGroupRules: Codable {
    let dropLowest: Int?
    let dropHighest: Int?
    let neverDrop: [Int]?
}

struct AssignmentGroup: Codable {
    let id: Int
    let name: String
    let groupWeight: Double
    let rules: AssignmentGroupRules?
    let assignments: [Assignment]
}

struct Assignment: Codable {
    let id: Int
    let name: String
    let pointsPossible: Double
    let dueAt: String?
    let assignmentGroupId: Int
}

struct Submission: Codable {
    let assignmentId: Int
    let score: Double?
    let workflowState: String
}

struct GradedItem {
    let assignmentId: Int
    let name: String
    let groupId: Int
    let pointsPossible: Double
    var earnedPoints: Double?
    var whatIfPoints: Double?
}
