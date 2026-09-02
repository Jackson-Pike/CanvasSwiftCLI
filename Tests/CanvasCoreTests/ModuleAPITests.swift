import XCTest
@testable import CanvasCore

final class ModuleAPITests: XCTestCase {
    func testDemoModulesReturnsMockData() async throws {
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        let modules = try await client.modules(courseId: 101)
        XCTAssertFalse(modules.isEmpty)
        XCTAssertEqual(modules.first?.id, 10101)
        XCTAssertFalse(modules.first?.items?.isEmpty ?? true)
    }
}
