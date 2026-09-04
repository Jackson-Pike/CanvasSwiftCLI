import XCTest
import SwiftData
@testable import CanvasData
@testable import CanvasCore

final class SubmissionDraftTests: XCTestCase {
    @MainActor
    func testDraftModelInsertsAndFetches() throws {
        let container = try CanvasStore.container(inMemory: true)
        let ctx = ModelContext(container)
        ctx.insert(CachedSubmissionDraft(assignmentId: 7, courseId: 42,
                                         submissionTypeRaw: "online_text_entry", text: "wip"))
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CachedSubmissionDraft>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.text, "wip")
    }
}

extension SubmissionDraftTests {
    @MainActor
    func testRepositoryReadsDraft() throws {
        let container = try CanvasStore.container(inMemory: true)
        let repo = CanvasRepository(modelContainer: container)
        let ctx = repo.modelContainer.mainContext
        ctx.insert(CachedSubmissionDraft(assignmentId: 7, courseId: 42,
                                         submissionTypeRaw: "online_url", url: "https://x"))
        try ctx.save()
        let draft = try repo.submissionDraft(assignmentId: 7)
        XCTAssertEqual(draft?.url, "https://x")
        XCTAssertNil(try repo.submissionDraft(assignmentId: 999))
    }
}
