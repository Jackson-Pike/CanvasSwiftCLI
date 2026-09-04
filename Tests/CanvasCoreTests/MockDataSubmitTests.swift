import XCTest
@testable import CanvasCore

final class MockDataSubmitTests: XCTestCase {
    // MockData.submissions is process-global mutable state; capture and restore around each test.
    var saved: [Int: [Submission]] = [:]
    override func setUp() { super.setUp(); saved = MockData.submissions }
    override func tearDown() { MockData.submissions = saved; super.tearDown() }

    func testDemoSubmitIncrementsAttemptAndMarksSubmitted() {
        // Pick a real demo assignment id from the CS course (assignmentId 201, "Week 1 Reflection",
        // csCourseId = 99999). Note: MockData.hwId (1001) is the assignment GROUP id, not an
        // assignment id — no submission exists with assignmentId 1001, so 201 is used instead.
        let before = MockData.submissions[99999]?.first { $0.assignmentId == 201 }?.attempt ?? 0
        let sub = MockData.demoSubmit(courseId: 99999, assignmentId: 201,
                                      type: .onlineText, text: "my answer", url: nil, fileIds: [])
        XCTAssertEqual(sub.workflowState, "submitted")
        XCTAssertEqual(sub.attempt, before + 1)
        XCTAssertNotNil(sub.submittedAt)
        // and the store now reflects it
        let stored = MockData.submissions[99999]?.first { $0.assignmentId == 201 }
        XCTAssertEqual(stored?.attempt, before + 1)
    }

    func testDemoCurrentSubmissionReflectsLatestSubmit() {
        _ = MockData.demoSubmit(courseId: 99999, assignmentId: 201, type: .onlineURL,
                                text: nil, url: "https://example.com", fileIds: [])
        let current = MockData.demoCurrentSubmission(courseId: 99999, assignmentId: 201)
        XCTAssertEqual(current.workflowState, "submitted")
    }

    func testDemoUploadSlotAndFileId() {
        let ticket = MockData.demoUploadSlot(name: "a.pdf", contentType: "application/pdf")
        XCTAssertFalse(ticket.uploadURL.isEmpty)
        XCTAssertTrue(MockData.demoUploadedFileId() > 0)
    }
}
