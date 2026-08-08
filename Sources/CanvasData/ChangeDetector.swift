import Foundation
import CanvasCore

public struct SubmissionSnapshot: Equatable, Sendable {
    public let score: Double?
    public let workflowState: String
    public let commentIds: Set<Int>
    public init(score: Double?, workflowState: String, commentIds: Set<Int>) {
        self.score = score
        self.workflowState = workflowState
        self.commentIds = commentIds
    }
}

public struct PendingChange: Equatable, Sendable {
    public let kind: ChangeKind
    public let courseId: Int
    public let subjectId: Int?
    public let title: String
    public let detail: String?
    public init(kind: ChangeKind, courseId: Int, subjectId: Int?, title: String, detail: String?) {
        self.kind = kind
        self.courseId = courseId
        self.subjectId = subjectId
        self.title = title
        self.detail = detail
    }
}

public enum ChangeDetector {
    /// .newGrade and .newFeedback. `old` is keyed by assignmentId.
    ///
    /// Returns [] when `isBaseline` (first successful submissions sync for this course =
    /// no flood). This must be driven by whether a prior sync *succeeded*, not by
    /// `old.isEmpty`: a course that legitimately returned zero submissions on earlier
    /// syncs (start of term) would otherwise swallow the entire first real batch of grades.
    public static func submissionChanges(courseId: Int,
                                         old: [Int: SubmissionSnapshot],
                                         new: [Submission],
                                         assignmentNames: [Int: String],
                                         isBaseline: Bool) -> [PendingChange] {
        guard !isBaseline else { return [] }
        var changes: [PendingChange] = []
        for sub in new {
            let prior = old[sub.assignmentId]
            let name = assignmentNames[sub.assignmentId] ?? "Assignment"
            // Muted grade (graded + nil score) never fires — the `if let score` guard enforces it.
            if let score = sub.score, sub.workflowState == "graded", prior?.score != score {
                changes.append(PendingChange(kind: .newGrade, courseId: courseId,
                                             subjectId: sub.assignmentId, title: name,
                                             detail: String(format: "%.1f", score)))
            }
            for comment in sub.submissionComments ?? [] where comment.authorId != sub.userId {
                guard let cid = comment.id else { continue }
                if !(prior?.commentIds.contains(cid) ?? false) {
                    changes.append(PendingChange(kind: .newFeedback, courseId: courseId,
                                                 subjectId: sub.assignmentId, title: name,
                                                 detail: "\(comment.authorName): \(comment.comment)"))
                }
            }
        }
        return changes
    }

    /// .gradeChanged — nil unless both non-nil and |new-old| >= 0.01.
    public static func gradeChange(courseId: Int, courseName: String,
                                   oldPercent: Double?, newPercent: Double?) -> PendingChange? {
        guard let o = oldPercent, let n = newPercent, abs(n - o) >= 0.01 else { return nil }
        return PendingChange(kind: .gradeChanged, courseId: courseId, subjectId: nil, title: courseName,
                             detail: String(format: "%.1f%% → %.1f%%", o, n))
    }

    /// .dueSoon — dueAt within (now, now+24h], not submitted, not already notified.
    public static func dueSoonChanges(courseId: Int,
                                      assignments: [(id: Int, name: String, dueAt: Date?)],
                                      submittedAssignmentIds: Set<Int>,
                                      alreadyNotified: Set<Int>,
                                      now: Date) -> [PendingChange] {
        assignments.compactMap { a in
            guard let due = a.dueAt, due > now, due <= now.addingTimeInterval(86_400),
                  !submittedAssignmentIds.contains(a.id), !alreadyNotified.contains(a.id) else { return nil }
            return PendingChange(kind: .dueSoon, courseId: courseId, subjectId: a.id, title: a.name, detail: nil)
        }
    }

    /// .newMessage — fires when a conversation is `unread` and its `lastMessageAt` has advanced
    /// beyond the stored value (or it is newly seen). `courseId` is 0: conversations are not
    /// course-scoped in this model; `subjectId` is the conversationId so a notification tap can
    /// reveal the thread. Baseline-suppressed on the first inbox sync (spec deviation, §3.1).
    public static func conversationChanges(old: [Int: Date?], new: [Conversation],
                                           isBaseline: Bool) -> [PendingChange] {
        guard !isBaseline else { return [] }
        var changes: [PendingChange] = []
        for c in new where c.workflowState == "unread" {
            let newDate = CanvasDate.parse(c.lastMessageAt)
            let priorDate = old[c.id] ?? nil
            let advanced: Bool
            if let newDate, let priorDate { advanced = newDate > priorDate }
            else if newDate != nil, old[c.id] == nil { advanced = true }   // brand new
            else { advanced = false }
            guard advanced else { continue }
            changes.append(PendingChange(kind: .newMessage, courseId: 0, subjectId: c.id,
                                         title: c.subject ?? "New message",
                                         detail: c.lastMessage))
        }
        return changes
    }
}
