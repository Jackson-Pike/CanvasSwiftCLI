import Foundation
import SwiftData

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

    public init(id: Int, assignmentId: Int, courseId: Int, userId: Int, score: Double?,
                workflowState: String, gradedAt: Date?, submittedAt: Date?) {
        self.id = id; self.assignmentId = assignmentId; self.courseId = courseId
        self.userId = userId; self.score = score; self.workflowState = workflowState
        self.gradedAt = gradedAt; self.submittedAt = submittedAt
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
