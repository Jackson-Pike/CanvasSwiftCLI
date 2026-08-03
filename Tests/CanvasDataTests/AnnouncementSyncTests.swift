import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class AnnouncementSyncTests: XCTestCase {

    func testCourseSyncPopulatesAnnouncements() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        let courseId = MockData.csCourseId
        try await engine.refresh(.course(courseId))

        let expected = MockData.announcements[courseId] ?? []
        let fetched: [CachedAnnouncement] = try await MainActor.run {
            let ctx = container.mainContext
            let predicate = #Predicate<CachedAnnouncement> { $0.courseId == courseId }
            return try ctx.fetch(FetchDescriptor(predicate: predicate))
        }
        XCTAssertEqual(fetched.count, expected.count)
    }

    /// `readAt` is device-local — a re-sync must never clobber it. This test fails if
    /// `upsertAnnouncements` ever assigns `row.readAt` on the update branch.
    func testAnnouncementResyncPreservesReadAt() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        let courseId = MockData.csCourseId
        try await engine.refresh(.course(courseId))

        let firstAnnouncementId = (MockData.announcements[courseId] ?? []).first?.id
        XCTAssertNotNil(firstAnnouncementId)
        let readMoment = Date()

        try await MainActor.run {
            let ctx = container.mainContext
            let predicate = #Predicate<CachedAnnouncement> { $0.id == firstAnnouncementId! }
            let row = try ctx.fetch(FetchDescriptor(predicate: predicate)).first
            XCTAssertNotNil(row)
            row?.readAt = readMoment
            try ctx.save()
        }

        try await engine.refresh(.course(courseId), force: true)

        let readAtAfterResync: Date? = try await MainActor.run {
            let ctx = container.mainContext
            let predicate = #Predicate<CachedAnnouncement> { $0.id == firstAnnouncementId! }
            return try ctx.fetch(FetchDescriptor(predicate: predicate)).first?.readAt
        }
        XCTAssertEqual(readAtAfterResync, readMoment)
    }
}
