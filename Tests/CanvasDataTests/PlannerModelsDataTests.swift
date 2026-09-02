import XCTest
import SwiftData
@testable import CanvasCore
@testable import CanvasData

final class PlannerModelsDataTests: XCTestCase {
    @MainActor
    func testStoreContainerWithPlannerModels() throws {
        let container = try CanvasStore.container(inMemory: true)
        let ctx = container.mainContext

        let item = CachedPlannerItem(
            id: "assignment_101",
            title: "Midterm Essay",
            courseId: 101,
            plannableId: 55,
            plannableType: "assignment",
            plannableDate: Date(),
            htmlUrl: "https://example.com"
        )
        ctx.insert(item)

        let event = CachedCalendarEvent(
            id: 202,
            title: "Study Group",
            contextCode: "course_101",
            courseId: 101,
            startAt: Date(),
            endAt: Date().addingTimeInterval(3600),
            locationName: "Library",
            eventDescription: nil,
            htmlUrl: nil
        )
        ctx.insert(event)

        try ctx.save()

        let fetchedItems = try ctx.fetch(FetchDescriptor<CachedPlannerItem>())
        XCTAssertEqual(fetchedItems.count, 1)
        XCTAssertEqual(fetchedItems.first?.title, "Midterm Essay")

        let fetchedEvents = try ctx.fetch(FetchDescriptor<CachedCalendarEvent>())
        XCTAssertEqual(fetchedEvents.count, 1)
        XCTAssertEqual(fetchedEvents.first?.title, "Study Group")
    }
}
