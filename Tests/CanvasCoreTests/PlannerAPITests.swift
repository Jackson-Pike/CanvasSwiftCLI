import XCTest
@testable import CanvasCore

final class PlannerAPITests: XCTestCase {
    func testPlannerItemsDemoMode() async throws {
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        let items = try await client.plannerItems()
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.contains(where: { $0.id == "assignment_202" }))
    }
}
