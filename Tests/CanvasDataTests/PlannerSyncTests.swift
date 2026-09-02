import XCTest
import SwiftData
@testable import CanvasCore
@testable import CanvasData

final class PlannerSyncTests: XCTestCase {
    @MainActor
    func testSyncPlannerUpsertsItemsAndEvents() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        let start = Date().addingTimeInterval(-7 * 86400)
        let end = Date().addingTimeInterval(14 * 86400)

        try await engine.refresh(.planner(start: start, end: end))

        let repo = CanvasRepository(modelContainer: container)
        let items = try await repo.plannerItems(start: start, end: end)
        let events = try await repo.calendarEvents(start: start, end: end)

        XCTAssertFalse(items.isEmpty)
        XCTAssertFalse(events.isEmpty)
    }
}
