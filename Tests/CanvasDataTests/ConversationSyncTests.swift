import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class ConversationSyncTests: XCTestCase {
    func testSchemaRoundTripsConversationAndMessage() async throws {
        let container = try CanvasStore.container(inMemory: true)
        try await MainActor.run {
            let ctx = container.mainContext
            ctx.insert(CachedConversation(id: 5, subject: "Hi", lastMessageAt: Date(),
                                          lastMessageSnippet: "yo", workflowState: "unread",
                                          participantsJSON: nil, contextName: "BIOL 100", messageCount: 1))
            ctx.insert(CachedMessage(id: 9, conversationId: 5, authorId: 1, authorName: "Dr. Reed",
                                     body: "yo", createdAt: Date(), pending: false))
            try ctx.save()
            let repo = CanvasRepository(modelContainer: container)
            XCTAssertEqual(try repo.conversation(id: 5)?.subject, "Hi")
            XCTAssertEqual(try repo.messages(conversationId: 5).count, 1)
        }
    }

    func testConversationsScopeFilter() async throws {
        let container = try CanvasStore.container(inMemory: true)
        try await MainActor.run {
            let ctx = container.mainContext
            ctx.insert(CachedConversation(id: 1, subject: "a", lastMessageAt: Date(), lastMessageSnippet: nil,
                                          workflowState: "unread", participantsJSON: nil, contextName: nil, messageCount: 1))
            ctx.insert(CachedConversation(id: 2, subject: "b", lastMessageAt: Date(), lastMessageSnippet: nil,
                                          workflowState: "read", participantsJSON: nil, contextName: nil, messageCount: 1))
            ctx.insert(CachedConversation(id: 3, subject: "c", lastMessageAt: Date(), lastMessageSnippet: nil,
                                          workflowState: "archived", participantsJSON: nil, contextName: nil, messageCount: 1))
            try ctx.save()
            let repo = CanvasRepository(modelContainer: container)
            XCTAssertEqual(try repo.conversations(scope: .inbox).count, 2)     // unread + read, not archived
            XCTAssertEqual(try repo.conversations(scope: .unread).count, 1)
            XCTAssertEqual(try repo.conversations(scope: .archived).count, 1)
        }
    }

    func testInboxSyncPopulatesConversations() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        try await engine.refresh(.inbox)
        let count = try await MainActor.run {
            try CanvasRepository(modelContainer: container).conversations(scope: .inbox).count
        }
        XCTAssertEqual(count, 2)   // demo inbox = unread + read (archived excluded)
    }

    func testPurgeRemovesLongDeadConversation() async throws {
        let container = try CanvasStore.container(inMemory: true)
        try await MainActor.run {
            let ctx = container.mainContext
            let old = CachedConversation(id: 1, subject: "old", lastMessageAt: Date(), lastMessageSnippet: nil,
                                         workflowState: "read", participantsJSON: nil, contextName: nil, messageCount: 1)
            old.removedAt = Date().addingTimeInterval(-100 * 86400)   // 100 days ago > 90-day threshold
            ctx.insert(old); try ctx.save()
            let repo = CanvasRepository(modelContainer: container)
            try repo.purgeExpired()
            XCTAssertNil(try repo.conversation(id: 1))
        }
    }

    func testInboxResyncIsIdempotent() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        try await engine.refresh(.inbox)
        try await engine.refresh(.inbox, force: true)
        let count = try await MainActor.run {
            try CanvasRepository(modelContainer: container).conversations(scope: .inbox).count
        }
        XCTAssertEqual(count, 2)   // no duplicates
    }
}
