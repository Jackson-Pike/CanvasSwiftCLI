import XCTest
@testable import CanvasCore
@testable import CanvasData

final class DueSoonChangeTests: XCTestCase {
    func testDueSoonFiresWhenAssignmentEnters24HourWindowUnsubmitted() {
        let now = Date()
        let dueIn12Hours = now.addingTimeInterval(12 * 3600)

        let assignments = [(id: 99, name: "Physics Quiz", dueAt: Optional(dueIn12Hours))]

        let records = ChangeDetector.dueSoonChanges(
            courseId: 101,
            assignments: assignments,
            submittedAssignmentIds: [],
            alreadyNotified: [],
            now: now
        )
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.kind, .dueSoon)
        XCTAssertEqual(records.first?.title, "Physics Quiz")
    }
}
