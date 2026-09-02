import XCTest
@testable import CanvasCore

final class CalendarModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func testCalendarEventDecodes() throws {
        let json = Data(#"""
        {
            "id": 404,
            "title": "Study Group",
            "context_code": "course_101",
            "start_at": "2026-08-12T14:00:00Z",
            "end_at": "2026-08-12T15:30:00Z",
            "location_name": "Library Room 204",
            "description": "<p>Reviewing Chapter 4</p>",
            "html_url": "https://byuh.instructure.com/calendar?event_id=404"
        }
        """#.utf8)

        let event = try decoder().decode(CalendarEvent.self, from: json)
        XCTAssertEqual(event.id, 404)
        XCTAssertEqual(event.title, "Study Group")
        XCTAssertEqual(event.contextCode, "course_101")
        XCTAssertEqual(event.courseId, 101)
        XCTAssertEqual(event.locationName, "Library Room 204")
    }
}
