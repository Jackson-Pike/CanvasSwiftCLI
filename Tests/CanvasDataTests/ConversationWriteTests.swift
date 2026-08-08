import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class ConversationWriteTests: XCTestCase {
    private func makeEngine() async throws -> (SyncEngine, ModelContainer) {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        return (engine, container)
    }

    func testMarkReadUpdatesWorkflowState() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.inbox)
        try await engine.markConversationRead(5001)
        let state = try await MainActor.run {
            try CanvasRepository(modelContainer: container).conversation(id: 5001)?.workflowState
        }
        XCTAssertEqual(state, "read")
    }

    func testSendReplyReconcilesPendingWithReal() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.inbox)
        try await engine.refresh(.conversation(5001))
        let before = try await MainActor.run {
            try CanvasRepository(modelContainer: container).messages(conversationId: 5001).count
        }
        try await engine.sendReply(conversationId: 5001, body: "Got it, thanks!")
        let (after, anyPending) = try await MainActor.run { () -> (Int, Bool) in
            let msgs = try CanvasRepository(modelContainer: container).messages(conversationId: 5001)
            return (msgs.count, msgs.contains { $0.pending })
        }
        XCTAssertEqual(after, before + 1)
        XCTAssertFalse(anyPending)   // reconciled: no orphaned optimistic row
    }

    func testComposeReturnsNewConversationId() async throws {
        let (engine, container) = try await makeEngine()
        let newId = try await engine.compose(recipientIds: [MockData.teacherUserId], subject: "Question", body: "Hi")
        let exists = try await MainActor.run {
            try CanvasRepository(modelContainer: container).conversation(id: newId) != nil
        }
        XCTAssertTrue(exists)
    }
}
