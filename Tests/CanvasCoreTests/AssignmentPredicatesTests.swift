import XCTest
@testable import CanvasCore

final class AssignmentPredicatesTests: XCTestCase {
    // Fixed dates for deterministic testing
    private let pastDate = Date(timeIntervalSince1970: 1000000)  // Sept 9, 1970
    private let futureDate = Date(timeIntervalSince1970: 2000000000)  // May 18, 2033
    private let now = Date(timeIntervalSince1970: 1500000)  // Oct 17, 1970

    // MARK: - isAssignmentMissing Tests

    func testMissingFlagTrueOverridesFutureDate() {
        // missingFlag == true should override even a future due date
        let result = isAssignmentMissing(
            dueAt: futureDate,
            submissionWorkflowState: nil,
            missingFlag: true,
            now: now
        )
        XCTAssertTrue(result)
    }

    func testPastDueWithNoSubmissionIsMissing() {
        // past-due with nil workflowState → missing
        let result = isAssignmentMissing(
            dueAt: pastDate,
            submissionWorkflowState: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertTrue(result)
    }

    func testPastDueWithUnsubmittedStateIsMissing() {
        // past-due with workflowState == "unsubmitted" → missing
        let result = isAssignmentMissing(
            dueAt: pastDate,
            submissionWorkflowState: "unsubmitted",
            missingFlag: false,
            now: now
        )
        XCTAssertTrue(result)
    }

    func testFutureDueIsNotMissing() {
        // future due date → not missing
        let result = isAssignmentMissing(
            dueAt: futureDate,
            submissionWorkflowState: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertFalse(result)
    }

    func testGradedIsNotMissing() {
        // past-due but graded → not missing
        let result = isAssignmentMissing(
            dueAt: pastDate,
            submissionWorkflowState: "graded",
            missingFlag: false,
            now: now
        )
        XCTAssertFalse(result)
    }

    func testMissingFlagNilTreatsAsDefault() {
        // missingFlag == nil should not override
        let result = isAssignmentMissing(
            dueAt: futureDate,
            submissionWorkflowState: nil,
            missingFlag: nil,
            now: now
        )
        XCTAssertFalse(result)
    }

    func testPastDueWithSubmittedStateIsNotMissing() {
        // past-due but submitted (not unsubmitted) → not missing
        let result = isAssignmentMissing(
            dueAt: pastDate,
            submissionWorkflowState: "submitted",
            missingFlag: false,
            now: now
        )
        XCTAssertFalse(result)
    }

    // MARK: - assignmentMatchesFilter Tests

    func testFilterAll() {
        // .all should always return true
        XCTAssertTrue(assignmentMatchesFilter(.all, dueAt: nil, workflowState: nil, score: nil, missingFlag: nil, now: now))
        XCTAssertTrue(assignmentMatchesFilter(.all, dueAt: pastDate, workflowState: "graded", score: 90.0, missingFlag: true, now: now))
    }

    func testFilterMissingPastDueNoSubmission() {
        // .missing with past due and no submission → true
        let result = assignmentMatchesFilter(
            .missing,
            dueAt: pastDate,
            workflowState: nil,
            score: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertTrue(result)
    }

    func testFilterMissingPastDueUnsubmitted() {
        // .missing with past due and unsubmitted → true
        let result = assignmentMatchesFilter(
            .missing,
            dueAt: pastDate,
            workflowState: "unsubmitted",
            score: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertTrue(result)
    }

    func testFilterMissingFutureDue() {
        // .missing with future due → false
        let result = assignmentMatchesFilter(
            .missing,
            dueAt: futureDate,
            workflowState: nil,
            score: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertFalse(result)
    }

    func testFilterMissingWithFlag() {
        // .missing with missingFlag == true → true
        let result = assignmentMatchesFilter(
            .missing,
            dueAt: futureDate,
            workflowState: nil,
            score: nil,
            missingFlag: true,
            now: now
        )
        XCTAssertTrue(result)
    }

    func testFilterGradedWithGradedState() {
        // .graded with workflowState == "graded" and score != nil → true
        let result = assignmentMatchesFilter(
            .graded,
            dueAt: pastDate,
            workflowState: "graded",
            score: 85.5,
            missingFlag: false,
            now: now
        )
        XCTAssertTrue(result)
    }

    func testFilterGradedWithoutScore() {
        // .graded with workflowState == "graded" but score == nil → false
        let result = assignmentMatchesFilter(
            .graded,
            dueAt: pastDate,
            workflowState: "graded",
            score: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertFalse(result)
    }

    func testFilterGradedWithWrongState() {
        // .graded with workflowState != "graded" → false
        let result = assignmentMatchesFilter(
            .graded,
            dueAt: pastDate,
            workflowState: "submitted",
            score: 85.5,
            missingFlag: false,
            now: now
        )
        XCTAssertFalse(result)
    }

    func testFilterUpcomingWithFutureDue() {
        // .upcoming with future due date → true
        let result = assignmentMatchesFilter(
            .upcoming,
            dueAt: futureDate,
            workflowState: nil,
            score: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertTrue(result)
    }

    func testFilterUpcomingWithPastDue() {
        // .upcoming with past due date → false
        let result = assignmentMatchesFilter(
            .upcoming,
            dueAt: pastDate,
            workflowState: nil,
            score: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertFalse(result)
    }

    func testFilterUpcomingWithNilDue() {
        // .upcoming with nil due date → false
        let result = assignmentMatchesFilter(
            .upcoming,
            dueAt: nil,
            workflowState: nil,
            score: nil,
            missingFlag: false,
            now: now
        )
        XCTAssertFalse(result)
    }
}
