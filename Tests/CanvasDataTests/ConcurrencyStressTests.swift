import XCTest
import SwiftData
@testable import CanvasData
import CanvasCore

final class ConcurrencyStressTests: XCTestCase {
    @MainActor
    func testConcurrentSyncAndReads() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let repository = CanvasRepository(modelContainer: container)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(
            credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))

        let writer = Task {
            for _ in 0..<10 {
                try await engine.refresh(.all, force: true)
                for id in [MockData.csCourseId, MockData.mathCourseId] {
                    try await engine.refresh(.course(id), force: true)
                }
            }
        }
        for _ in 0..<500 {
            _ = try repository.courses()
            _ = try repository.calculatorInputs(courseId: MockData.csCourseId)
            _ = try repository.stream(courseId: MockData.csCourseId)
            await Task.yield()
        }
        try await writer.value
        XCTAssertEqual(try repository.courses(includeHidden: true).count, MockData.courses.count)
    }
}
