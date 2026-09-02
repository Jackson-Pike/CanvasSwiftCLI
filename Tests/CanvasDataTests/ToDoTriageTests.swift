import XCTest
import SwiftData
@testable import CanvasCore
@testable import CanvasData

final class ToDoTriageTests: XCTestCase {
    @MainActor
    func testToDoTriaging() throws {
        let container = try CanvasStore.container(inMemory: true)
        let ctx = container.mainContext

        let now = Date()

        // 1. Missing item
        let missingItem = CachedPlannerItem(
            id: "missing_1",
            title: "Overdue Assignment",
            courseId: 101,
            plannableId: 1,
            plannableType: "assignment",
            plannableDate: now.addingTimeInterval(-2 * 86400),
            htmlUrl: nil,
            isSubmitted: false,
            isMissing: true
        )
        ctx.insert(missingItem)

        // 2. Due this week item
        let dueThisWeekItem = CachedPlannerItem(
            id: "due_week_1",
            title: "Upcoming Project",
            courseId: 101,
            plannableId: 2,
            plannableType: "assignment",
            plannableDate: now.addingTimeInterval(3 * 86400),
            htmlUrl: nil,
            isSubmitted: false,
            isMissing: false
        )
        ctx.insert(dueThisWeekItem)

        // 3. Awaiting grade submission
        let awaitingSub = CachedSubmission(
            id: 501,
            assignmentId: 3,
            courseId: 101,
            userId: 77777,
            score: nil,
            workflowState: "submitted",
            gradedAt: nil,
            submittedAt: now.addingTimeInterval(-1 * 86400)
        )
        ctx.insert(awaitingSub)

        try ctx.save()

        let repo = CanvasRepository(modelContainer: container)

        let missing = try repo.toDoMissing(now: now)
        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing.first?.id, "missing_1")

        let dueThisWeek = try repo.toDoDueThisWeek(now: now)
        XCTAssertEqual(dueThisWeek.count, 1)
        XCTAssertEqual(dueThisWeek.first?.id, "due_week_1")

        let awaitingGrade = try repo.toDoAwaitingGrade()
        XCTAssertEqual(awaitingGrade.count, 1)
        XCTAssertEqual(awaitingGrade.first?.id, 501)
    }
}
