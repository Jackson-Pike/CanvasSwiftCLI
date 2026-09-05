import XCTest
@testable import CanvasCore

final class PlannerModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func testPlannerItemDecodes() throws {
        let json = Data(#"""
        {
            "id": "assignment_101",
            "title": "Midterm Essay",
            "course_id": 101,
            "plannable_id": 55,
            "plannable_type": "assignment",
            "plannable_date": "2026-08-15T23:59:00Z",
            "html_url": "https://byuh.instructure.com/courses/101/assignments/55",
            "submissions": {
                "submitted": false,
                "excused": false,
                "graded": false,
                "missing": false,
                "late": false,
                "has_feedback": false
            },
            "planner_override": {
                "id": 12,
                "marked_complete": false
            }
        }
        """#.utf8)

        let item = try decoder().decode(PlannerItem.self, from: json)
        XCTAssertEqual(item.id, "assignment_101")
        XCTAssertEqual(item.title, "Midterm Essay")
        XCTAssertEqual(item.courseId, 101)
        XCTAssertEqual(item.plannableId, 55)
        XCTAssertEqual(item.plannableType, "assignment")
        XCTAssertEqual(item.submissions?.submitted, false)
        XCTAssertEqual(item.plannerOverride?.markedComplete, false)
    }

    func testNestedPlannablePlannerItemDecodes() throws {
        let json = Data(#"""
        {
            "context_type": "Course",
            "course_id": 202,
            "plannable_id": 88,
            "plannable_type": "assignment",
            "plannable_date": "2026-09-10T15:30:00.123Z",
            "plannable": {
                "id": 88,
                "title": "Final Project Submission",
                "due_at": "2026-09-10T15:30:00.123Z"
            },
            "html_url": "https://byuh.instructure.com/courses/202/assignments/88"
        }
        """#.utf8)

        let item = try decoder().decode(PlannerItem.self, from: json)
        XCTAssertEqual(item.id, "assignment_88")
        XCTAssertEqual(item.title, "Final Project Submission")
        XCTAssertEqual(item.courseId, 202)
        XCTAssertEqual(item.plannableId, 88)
        XCTAssertEqual(item.plannableType, "assignment")
        XCTAssertNotNil(item.plannableDate)
    }

    func testBooleanSubmissionsPlannerItemDecodes() throws {
        let json = Data(#"""
        {
            "plannable_id": 99,
            "plannable_type": "quiz",
            "title": "Pop Quiz 1",
            "submissions": false
        }
        """#.utf8)

        let item = try decoder().decode(PlannerItem.self, from: json)
        XCTAssertEqual(item.id, "quiz_99")
        XCTAssertEqual(item.title, "Pop Quiz 1")
        XCTAssertEqual(item.submissions?.submitted, false)
    }
}
