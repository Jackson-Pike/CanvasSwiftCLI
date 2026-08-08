import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class DiscussionSyncTests: XCTestCase {
    private func makeEngine() async throws -> (SyncEngine, ModelContainer) {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        return (engine, container)
    }

    func testCourseSyncPopulatesDiscussionTopics() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.course(MockData.csCourseId))
        let count = try await MainActor.run {
            try CanvasRepository(modelContainer: container).discussionTopics(courseId: MockData.csCourseId).count
        }
        XCTAssertEqual(count, 2)
    }

    func testDiscussionEntriesSyncFlattensTree() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.course(MockData.csCourseId))
        try await engine.refresh(.discussion(courseId: MockData.csCourseId, topicId: 3001))
        let entries = try await MainActor.run {
            try CanvasRepository(modelContainer: container).discussionEntries(topicId: 3001)
        }
        XCTAssertEqual(entries.map(\.id), [4001, 4002, 4003])   // pre-order
        XCTAssertEqual(entries.map(\.depth), [0, 1, 0])
    }

    func testDiscussionEntriesResyncIsIdempotent() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.course(MockData.csCourseId))
        try await engine.refresh(.discussion(courseId: MockData.csCourseId, topicId: 3001))
        try await engine.refresh(.discussion(courseId: MockData.csCourseId, topicId: 3001), force: true)
        let count = try await MainActor.run {
            try CanvasRepository(modelContainer: container).discussionEntries(topicId: 3001).count
        }
        XCTAssertEqual(count, 3)
    }
}
