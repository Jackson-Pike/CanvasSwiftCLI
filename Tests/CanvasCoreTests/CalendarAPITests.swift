import XCTest
@testable import CanvasCore

final class CalendarAPITests: XCTestCase {
    func testCalendarEventsDemoMode() async throws {
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        let events = try await client.calendarEvents()
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.contains(where: { $0.id == 9001 }))
    }
}
