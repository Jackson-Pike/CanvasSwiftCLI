import Foundation
import SwiftData

/// A locally-persisted, unsent submission draft for one assignment. Text/URL only — file
/// selections are session-only (spec §7 draft scope decision). Keyed uniquely by assignmentId:
/// a student has at most one in-progress draft per assignment.
@Model
public final class CachedSubmissionDraft {
    @Attribute(.unique) public var assignmentId: Int
    public var courseId: Int
    public var submissionTypeRaw: String
    public var text: String?
    public var url: String?
    public var updatedAt: Date

    public init(assignmentId: Int, courseId: Int, submissionTypeRaw: String,
                text: String? = nil, url: String? = nil, updatedAt: Date = Date()) {
        self.assignmentId = assignmentId
        self.courseId = courseId
        self.submissionTypeRaw = submissionTypeRaw
        self.text = text
        self.url = url
        self.updatedAt = updatedAt
    }
}
