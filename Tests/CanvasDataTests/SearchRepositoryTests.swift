import XCTest
import SwiftData
@testable import CanvasCore
@testable import CanvasData

final class SearchRepositoryTests: XCTestCase {
    @MainActor
    func testSearchQueriesAcrossEntities() throws {
        let container = try CanvasStore.container(inMemory: true)
        let repo = CanvasRepository(modelContainer: container)
        let ctx = container.mainContext

        let course = CachedCourse(id: 101, name: "Biology 101", courseCode: "BIOL 101", applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 0)
        let assignment = CachedAssignment(id: 201, courseId: 101, groupId: 1, name: "Cell Structure Essay", pointsPossible: 50, dueAt: nil, sortIndex: 0)
        let file = CachedFile(id: 301, courseId: 101, displayName: "Biology_Lab_Guide.pdf", size: 1000)

        ctx.insert(course)
        ctx.insert(assignment)
        ctx.insert(file)
        try ctx.save()

        let cellResults = try repo.search(query: "Cell")
        XCTAssertFalse(cellResults.isEmpty)
        XCTAssertEqual(cellResults.first?.title, "Cell Structure Essay")

        let bioResults = try repo.search(query: "Biology")
        XCTAssertEqual(bioResults.count, 2) // Course and File
    }
}
