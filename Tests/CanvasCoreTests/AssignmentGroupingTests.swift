import XCTest
@testable import CanvasCore

final class AssignmentGroupingTests: XCTestCase {
    // A fixed UTC calendar so day-boundary math is deterministic across machines.
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    // 2026-09-04 12:00 UTC — matches the mockup's "today".
    private let now = Date(timeIntervalSince1970: 1_788_523_200)

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        // offset calendar days from `now`, at the given hour.
        let base = cal.startOfDay(for: now)
        return cal.date(byAdding: .day, value: offset, to: base)!.addingTimeInterval(TimeInterval(hour * 3600))
    }

    // MARK: - dueUrgency

    func testDueUrgencyNoDate() {
        XCTAssertEqual(dueUrgency(dueAt: nil, now: now, calendar: cal), .none)
    }

    func testDueUrgencyOverdue() {
        XCTAssertEqual(dueUrgency(dueAt: day(-1), now: now, calendar: cal), .overdue)
    }

    func testDueUrgencyToday() {
        // Earlier the same calendar day still reads as Today, not overdue.
        XCTAssertEqual(dueUrgency(dueAt: day(0, hour: 6), now: now, calendar: cal), .today)
    }

    func testDueUrgencySoon() {
        XCTAssertEqual(dueUrgency(dueAt: day(1), now: now, calendar: cal), .soon)
        XCTAssertEqual(dueUrgency(dueAt: day(4), now: now, calendar: cal), .soon)
    }

    func testDueUrgencyUpcoming() {
        XCTAssertEqual(dueUrgency(dueAt: day(5), now: now, calendar: cal), .upcoming)
        XCTAssertEqual(dueUrgency(dueAt: day(13), now: now, calendar: cal), .upcoming)
    }

    func testDueUrgencyLater() {
        XCTAssertEqual(dueUrgency(dueAt: day(14), now: now, calendar: cal), .later)
    }

    // MARK: - assignmentKind

    func testAssignmentKindMostSpecificWins() {
        // upload + text present → most specific listed first (Upload before Text).
        XCTAssertEqual(assignmentKind(submissionTypes: ["online_upload", "online_text_entry"]), "Upload")
        XCTAssertEqual(assignmentKind(submissionTypes: ["online_quiz"]), "Quiz")
        XCTAssertEqual(assignmentKind(submissionTypes: ["online_text_entry"]), "Text")
        XCTAssertEqual(assignmentKind(submissionTypes: ["online_url"]), "URL")
        XCTAssertEqual(assignmentKind(submissionTypes: ["external_tool"]), "External")
    }

    func testAssignmentKindEmptyIsNoSubmission() {
        XCTAssertEqual(assignmentKind(submissionTypes: []), "No submission")
        XCTAssertEqual(assignmentKind(submissionTypes: ["none"]), "No submission")
    }

    func testAssignmentKindUnknownIsOther() {
        XCTAssertEqual(assignmentKind(submissionTypes: ["some_future_type"]), "Other")
    }

    // MARK: - boardStatus

    func testBoardStatusGradedNeedsScore() {
        XCTAssertEqual(boardStatus(workflowState: "graded", score: 9, hasDraft: false), .graded)
        // muted grade (graded, withheld score) counts as submitted, not graded
        XCTAssertEqual(boardStatus(workflowState: "graded", score: nil, hasDraft: false), .submitted)
    }

    func testBoardStatusSubmitted() {
        XCTAssertEqual(boardStatus(workflowState: "submitted", score: nil, hasDraft: false), .submitted)
        XCTAssertEqual(boardStatus(workflowState: "pending_review", score: nil, hasDraft: false), .submitted)
    }

    func testBoardStatusInProgressOnlyWhenDraftAndNotSubmitted() {
        XCTAssertEqual(boardStatus(workflowState: nil, score: nil, hasDraft: true), .inProgress)
        XCTAssertEqual(boardStatus(workflowState: "unsubmitted", score: nil, hasDraft: true), .inProgress)
        // a draft does not override a real submission
        XCTAssertEqual(boardStatus(workflowState: "submitted", score: nil, hasDraft: true), .submitted)
    }

    func testBoardStatusNotSubmitted() {
        XCTAssertEqual(boardStatus(workflowState: nil, score: nil, hasDraft: false), .notSubmitted)
        XCTAssertEqual(boardStatus(workflowState: "unsubmitted", score: nil, hasDraft: false), .notSubmitted)
    }

    // MARK: - boardColumns

    private func mk(_ id: Int, due: Date? = nil, category: String = "Homework",
                    state: String? = nil, score: Double? = nil, draft: Bool = false) -> BoardAssignment {
        BoardAssignment(id: id, dueAt: due, category: category,
                        workflowState: state, score: score, hasDraft: draft)
    }

    func testStatusColumnsFixedAndExclusive() {
        let items = [
            mk(1, state: nil),                          // notSubmitted
            mk(2, state: "unsubmitted", draft: true),   // inProgress
            mk(3, state: "submitted"),                  // submitted
            mk(4, state: "graded", score: 10),          // graded
        ]
        let cols = boardColumns(for: .status, assignments: items, now: now, calendar: cal)
        XCTAssertEqual(cols.map(\.id), ["notSubmitted", "inProgress", "submitted", "graded"])
        XCTAssertEqual(cols[0].assignmentIds, [1])
        XCTAssertEqual(cols[1].assignmentIds, [2])
        XCTAssertEqual(cols[2].assignmentIds, [3])
        XCTAssertEqual(cols[3].assignmentIds, [4])
    }

    func testStatusColumnsPresentWhenEmpty() {
        let cols = boardColumns(for: .status, assignments: [mk(1, state: nil)], now: now, calendar: cal)
        XCTAssertEqual(cols.count, 4)                       // all four columns always present
        XCTAssertTrue(cols[3].assignmentIds.isEmpty)        // Graded empty
    }

    func testDueColumnsBucketAndSort() {
        let items = [
            mk(1, due: day(-2)),   // closed
            mk(2, due: day(3)),    // this week
            mk(3, due: day(0)),    // this week (sorts before id 2)
            mk(4, due: day(10)),   // next week
            mk(5, due: day(30)),   // later
            mk(6, due: nil),       // later (no due → last)
        ]
        let cols = boardColumns(for: .due, assignments: items, now: now, calendar: cal)
        XCTAssertEqual(cols.map(\.id), ["week", "next", "later", "closed"])
        XCTAssertEqual(cols[0].assignmentIds, [3, 2])   // soonest first within This week
        XCTAssertEqual(cols[1].assignmentIds, [4])
        XCTAssertEqual(cols[2].assignmentIds, [5, 6])   // dated before no-due
        XCTAssertEqual(cols[3].assignmentIds, [1])
    }

    func testTypeColumnsAreCanvasCategoriesAlphabetical() {
        let items = [
            mk(1, category: "Quizzes"),
            mk(2, category: "Homework"),
            mk(3, category: "Exams"),
            mk(4, category: "Homework"),
        ]
        let cols = boardColumns(for: .type, assignments: items, now: now, calendar: cal)
        // Only present categories, ordered alphabetically by name — no empty columns.
        XCTAssertEqual(cols.map(\.label), ["Exams", "Homework", "Quizzes"])
        XCTAssertEqual(cols.map { $0.assignmentIds }, [[3], [2, 4], [1]])
    }

    func testTypeColumnsSortByDueWithinCategory() {
        let items = [
            mk(1, due: day(5), category: "Homework"),
            mk(2, due: day(1), category: "Homework"),   // sorts before id 1
            mk(3, due: nil,    category: "Homework"),    // no-due sorts last
        ]
        let cols = boardColumns(for: .type, assignments: items, now: now, calendar: cal)
        XCTAssertEqual(cols.map(\.label), ["Homework"])
        XCTAssertEqual(cols[0].assignmentIds, [2, 1, 3])
    }
}
