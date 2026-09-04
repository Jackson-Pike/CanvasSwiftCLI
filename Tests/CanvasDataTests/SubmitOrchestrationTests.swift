import XCTest
import SwiftData
@testable import CanvasData
@testable import CanvasCore

final class SubmitOrchestrationTests: XCTestCase {
    var savedSubs: [Int: [Submission]] = [:]
    override func setUp() { super.setUp(); savedSubs = MockData.submissions }
    override func tearDown() { MockData.submissions = savedSubs; super.tearDown() }

    private func makeEngine() async throws -> SyncEngine {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        return engine
    }

    func testSubmitTextVerifiesAndUpsertsSubmission() async throws {
        let engine = try await makeEngine()
        let before = MockData.submissions[99999]?.first { $0.assignmentId == 201 }?.attempt ?? 0
        let verified = try await engine.submit(courseId: 99999, assignmentId: 201,
                                               type: .onlineText, text: "answer", url: nil, files: [])
        XCTAssertEqual(verified.workflowState, "submitted")
        XCTAssertEqual(verified.attempt, before + 1)
    }

    func testSubmitClearsDraft() async throws {
        let engine = try await makeEngine()
        try await engine.saveDraft(assignmentId: 201, courseId: 99999,
                                   type: .onlineText, text: "draft", url: nil)
        _ = try await engine.submit(courseId: 99999, assignmentId: 201,
                                    type: .onlineText, text: "final", url: nil, files: [])
        let count = try await engine.draftCountForTest(assignmentId: 201)
        XCTAssertEqual(count, 0)
    }

    func testSaveDraftIsIdempotentPerAssignment() async throws {
        let engine = try await makeEngine()
        try await engine.saveDraft(assignmentId: 201, courseId: 99999, type: .onlineText, text: "a", url: nil)
        try await engine.saveDraft(assignmentId: 201, courseId: 99999, type: .onlineText, text: "b", url: nil)
        let count = try await engine.draftCountForTest(assignmentId: 201)
        XCTAssertEqual(count, 1)   // upsert, not duplicate
    }
}
