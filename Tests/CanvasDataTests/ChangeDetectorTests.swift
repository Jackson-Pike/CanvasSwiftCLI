import XCTest
@testable import CanvasData
@testable import CanvasCore

final class ChangeDetectorTests: XCTestCase {

    // MARK: - Fixture helper

    private func makeSubmission(assignmentId: Int, userId: Int = 7, score: Double?, workflowState: String,
                                 comments: [(id: Int?, authorId: Int, authorName: String, comment: String)] = []) -> Submission {
        var dict: [String: Any] = [
            "id": assignmentId * 1000 + userId,
            "user_id": userId,
            "assignment_id": assignmentId,
            "score": score as Any,
            "workflow_state": workflowState,
            "graded_at": NSNull(),
            "submitted_at": NSNull(),
        ]
        if !comments.isEmpty {
            dict["submission_comments"] = comments.map { c -> [String: Any] in
                [
                    "id": c.id as Any,
                    "author_id": c.authorId,
                    "author_name": c.authorName,
                    "comment": c.comment,
                    "created_at": NSNull(),
                ]
            }
        }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try! decoder.decode(Submission.self, from: data)
    }

    // MARK: - .newGrade positives

    func testNewGradeFiresOnNilToScore() {
        let old: [Int: SubmissionSnapshot] = [100: SubmissionSnapshot(score: nil, workflowState: "graded", commentIds: [])]
        let sub = makeSubmission(assignmentId: 100, score: 92, workflowState: "graded")
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: old, new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .newGrade)
        XCTAssertEqual(changes.first?.courseId, 1)
        XCTAssertEqual(changes.first?.subjectId, 100)
        XCTAssertEqual(changes.first?.title, "HW1")
        XCTAssertEqual(changes.first?.detail, "92.0")
    }

    func testNewGradeFiresOnScoreChange() {
        let old: [Int: SubmissionSnapshot] = [100: SubmissionSnapshot(score: 80, workflowState: "graded", commentIds: [])]
        let sub = makeSubmission(assignmentId: 100, score: 85, workflowState: "graded")
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: old, new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .newGrade)
        XCTAssertEqual(changes.first?.detail, "85.0")
    }

    // MARK: - .newGrade negatives (Canvas quirks)

    func testMutedGradeDoesNotFireNewGrade() {
        // workflow_state "graded" but score nil (muted) must never fire, even against a baseline with a different score.
        let old: [Int: SubmissionSnapshot] = [100: SubmissionSnapshot(score: 70, workflowState: "graded", commentIds: [])]
        let sub = makeSubmission(assignmentId: 100, score: nil, workflowState: "graded")
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: old, new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertTrue(changes.isEmpty)
    }

    func testIdenticalResyncProducesZeroRecords() {
        let old: [Int: SubmissionSnapshot] = [100: SubmissionSnapshot(score: 85, workflowState: "graded", commentIds: [])]
        let sub = makeSubmission(assignmentId: 100, score: 85, workflowState: "graded")
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: old, new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertTrue(changes.isEmpty)
    }

    func testFirstSyncBaselineProducesZeroRecords() {
        let sub = makeSubmission(assignmentId: 100, score: 95, workflowState: "graded",
                                  comments: [(id: 1, authorId: 99, authorName: "Prof", comment: "Nice work")])
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: [:], new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertTrue(changes.isEmpty)
    }

    // MARK: - .newFeedback

    func testNewInstructorCommentFires() {
        let old: [Int: SubmissionSnapshot] = [100: SubmissionSnapshot(score: 85, workflowState: "graded", commentIds: [])]
        let sub = makeSubmission(assignmentId: 100, score: 85, workflowState: "graded",
                                  comments: [(id: 1, authorId: 99, authorName: "Prof Smith", comment: "Good job")])
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: old, new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .newFeedback)
        XCTAssertEqual(changes.first?.detail, "Prof Smith: Good job")
    }

    func testOwnCommentDoesNotFire() {
        let old: [Int: SubmissionSnapshot] = [100: SubmissionSnapshot(score: 85, workflowState: "graded", commentIds: [])]
        let sub = makeSubmission(assignmentId: 100, userId: 7, score: 85, workflowState: "graded",
                                  comments: [(id: 1, authorId: 7, authorName: "Me", comment: "self note")])
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: old, new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertTrue(changes.isEmpty)
    }

    func testExistingCommentDoesNotFire() {
        let old: [Int: SubmissionSnapshot] = [100: SubmissionSnapshot(score: 85, workflowState: "graded", commentIds: [1])]
        let sub = makeSubmission(assignmentId: 100, score: 85, workflowState: "graded",
                                  comments: [(id: 1, authorId: 99, authorName: "Prof", comment: "Good job")])
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: old, new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertTrue(changes.isEmpty)
    }

    func testCommentWithoutIdIsIgnored() {
        let old: [Int: SubmissionSnapshot] = [100: SubmissionSnapshot(score: 85, workflowState: "graded", commentIds: [])]
        let sub = makeSubmission(assignmentId: 100, score: 85, workflowState: "graded",
                                  comments: [(id: nil, authorId: 99, authorName: "Prof", comment: "Good job")])
        let changes = ChangeDetector.submissionChanges(courseId: 1, old: old, new: [sub], assignmentNames: [100: "HW1"])
        XCTAssertTrue(changes.isEmpty)
    }

    // MARK: - .gradeChanged

    func testGradeChangedThreshold() {
        XCTAssertNil(ChangeDetector.gradeChange(courseId: 1, courseName: "CS 246", oldPercent: 87.400, newPercent: 87.405))
        let fires = ChangeDetector.gradeChange(courseId: 1, courseName: "CS 246", oldPercent: 87.4, newPercent: 87.42)
        XCTAssertNotNil(fires)
        XCTAssertEqual(fires?.kind, .gradeChanged)
        XCTAssertEqual(fires?.courseId, 1)
        XCTAssertNil(fires?.subjectId)
        XCTAssertEqual(fires?.title, "CS 246")
        XCTAssertEqual(fires?.detail, "87.4% → 87.4%")
        XCTAssertNil(ChangeDetector.gradeChange(courseId: 1, courseName: "CS 246", oldPercent: nil, newPercent: 90))
    }

    // MARK: - .dueSoon

    func testDueSoonFiresInsideWindow() {
        let now = Date()
        let assignments: [(id: Int, name: String, dueAt: Date?)] = [
            (id: 1, name: "Essay", dueAt: now.addingTimeInterval(3 * 3600))
        ]
        let changes = ChangeDetector.dueSoonChanges(courseId: 1, assignments: assignments,
                                                     submittedAssignmentIds: [], alreadyNotified: [], now: now)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .dueSoon)
        XCTAssertEqual(changes.first?.courseId, 1)
        XCTAssertEqual(changes.first?.subjectId, 1)
        XCTAssertEqual(changes.first?.title, "Essay")
    }

    func testDueSoonRespectsSubmittedAndNotifiedAndWindow() {
        let now = Date()
        let assignments: [(id: Int, name: String, dueAt: Date?)] = [
            (id: 1, name: "Submitted", dueAt: now.addingTimeInterval(3 * 3600)),   // submitted -> no
            (id: 2, name: "Notified", dueAt: now.addingTimeInterval(3 * 3600)),    // already notified -> no
            (id: 3, name: "TooFar", dueAt: now.addingTimeInterval(30 * 3600)),     // outside window -> no
            (id: 4, name: "PastDue", dueAt: now.addingTimeInterval(-3600)),        // past due -> no
            (id: 5, name: "NoDueDate", dueAt: nil),                                // nil due -> no
        ]
        let changes = ChangeDetector.dueSoonChanges(courseId: 1, assignments: assignments,
                                                     submittedAssignmentIds: [1], alreadyNotified: [2], now: now)
        XCTAssertTrue(changes.isEmpty)
    }
}
