import XCTest
import SwiftData
@testable import CanvasCore
@testable import CanvasData

final class ModuleSyncTests: XCTestCase {
    @MainActor
    func testSyncModulesUpsertsModulesAndItems() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        try await engine.refresh(.modules(courseId: MockData.csCourseId))

        let context = container.mainContext
        let modules = try context.fetch(FetchDescriptor<CachedModule>())
        let items = try context.fetch(FetchDescriptor<CachedModuleItem>())

        XCTAssertFalse(modules.isEmpty)
        XCTAssertEqual(modules.first?.courseId, MockData.csCourseId)
        XCTAssertFalse(items.isEmpty)
        let moduleIds = Set(modules.map(\.id))
        XCTAssertTrue(items.allSatisfy { moduleIds.contains($0.moduleId) })
    }
}
