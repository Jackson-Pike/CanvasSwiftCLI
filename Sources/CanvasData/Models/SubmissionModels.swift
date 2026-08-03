import Foundation
import SwiftData
import CanvasCore

@Model
public final class CachedSubmission {
    @Attribute(.unique) public var id: Int
    public var assignmentId: Int
    public var courseId: Int
    public var userId: Int
    public var score: Double?
    public var workflowState: String
    public var gradedAt: Date?
    public var submittedAt: Date?
    public var late: Bool
    public var missing: Bool
    public var excused: Bool
    public var attempt: Int?
    public var rubricAssessmentJSON: Data?

    public init(id: Int, assignmentId: Int, courseId: Int, userId: Int, score: Double?,
                workflowState: String, gradedAt: Date?, submittedAt: Date?,
                late: Bool = false, missing: Bool = false, excused: Bool = false,
                attempt: Int? = nil, rubricAssessmentJSON: Data? = nil) {
        self.id = id; self.assignmentId = assignmentId; self.courseId = courseId
        self.userId = userId; self.score = score; self.workflowState = workflowState
        self.gradedAt = gradedAt; self.submittedAt = submittedAt
        self.late = late; self.missing = missing; self.excused = excused
        self.attempt = attempt; self.rubricAssessmentJSON = rubricAssessmentJSON
    }

    /// Decoded rubric assessment keyed by criterion id; empty when no JSON is stored or decode fails.
    public var rubricAssessment: [String: RubricAssessmentEntry] {
        guard let rubricAssessmentJSON, let a = try? JSONDecoder().decode([String: RubricAssessmentEntry].self, from: rubricAssessmentJSON) else { return [:] }
        return a
    }
}

@Model
public final class CachedComment {
    @Attribute(.unique) public var id: Int
    public var submissionId: Int
    public var assignmentId: Int
    public var authorId: Int
    public var authorName: String
    public var body: String
    public var createdAt: Date?

    public init(id: Int, submissionId: Int, assignmentId: Int, authorId: Int,
                authorName: String, body: String, createdAt: Date?) {
        self.id = id; self.submissionId = submissionId; self.assignmentId = assignmentId
        self.authorId = authorId; self.authorName = authorName
        self.body = body; self.createdAt = createdAt
    }
}
