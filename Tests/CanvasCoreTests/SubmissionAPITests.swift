import XCTest
@testable import CanvasCore

final class SubmissionAPITests: XCTestCase {
    var session: URLSession!
    var client: APIClient!

    override func setUp() {
        super.setUp()
        PaginationStub.pages = [:]
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PaginationStub.self]
        session = URLSession(configuration: config)
        client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "test-token"), session: session)
    }

    func testRequestUploadSlotDecodesTicket() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/42/assignments/7/submissions/self/files"
        PaginationStub.pages[url] = (
            #"{"upload_url":"https://up/x","upload_params":{"key":"k1"}}"#.data(using: .utf8)!, nil)
        let ticket = try await client.requestUploadSlot(courseId: 42, assignmentId: 7,
                                                        name: "essay.pdf", size: 1024, contentType: "application/pdf")
        XCTAssertEqual(ticket.uploadURL, "https://up/x")
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: ticket.uploadParams), ["key": "k1"])
    }

    func testSubmissionSelfDecodes() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/42/assignments/7/submissions/self"
        PaginationStub.pages[url] = (
            #"{"id":9,"user_id":1,"assignment_id":7,"workflow_state":"submitted","attempt":2,"submitted_at":"2026-09-03T10:00:00Z"}"#
                .data(using: .utf8)!, nil)
        let sub = try await client.submissionSelf(courseId: 42, assignmentId: 7)
        XCTAssertEqual(sub.attempt, 2)
        XCTAssertEqual(sub.workflowState, "submitted")
    }

    func testSubmitAssignmentDecodesReturnedSubmission() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/42/assignments/7/submissions"
        PaginationStub.pages[url] = (
            #"{"id":9,"user_id":1,"assignment_id":7,"workflow_state":"submitted","attempt":1}"#.data(using: .utf8)!, nil)
        let sub = try await client.submitAssignment(courseId: 42, assignmentId: 7,
                                                    type: .onlineText, text: "hi", url: nil, fileIds: [])
        XCTAssertEqual(sub.id, 9)
        XCTAssertEqual(sub.workflowState, "submitted")
    }
}
