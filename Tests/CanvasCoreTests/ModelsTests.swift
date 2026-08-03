import XCTest
@testable import CanvasCore

final class ModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }

    func testCourseDecodesSnakeCase() throws {
        let json = """
        [{"id":1,"name":"Data Structures","course_code":"CS 246","apply_assignment_group_weights":true}]
        """.data(using: .utf8)!
        let courses = try decoder().decode([Course].self, from: json)
        XCTAssertEqual(courses.first?.courseCode, "CS 246")
        XCTAssertTrue(courses.first!.applyAssignmentGroupWeights ?? false)
    }

    func testAssignmentGroupDecodesNestedAssignments() throws {
        let json = """
        [{"id":10,"name":"Homework","group_weight":40.0,"rules":null,
          "assignments":[{"id":100,"name":"HW1","points_possible":50.0,"due_at":null,"assignment_group_id":10}]}]
        """.data(using: .utf8)!
        let groups = try decoder().decode([AssignmentGroup].self, from: json)
        XCTAssertEqual(groups.first?.groupWeight, 40.0)
        XCTAssertEqual(groups.first?.assignments.first?.assignmentGroupId, 10)
        XCTAssertNil(groups.first?.assignments.first?.dueAt)
    }

    func testSubmissionDecodesNullScore() throws {
        let json = """
        [{"id":1,"user_id":1,"assignment_id":100,"score":null,"workflow_state":"unsubmitted"}]
        """.data(using: .utf8)!
        let subs = try decoder().decode([Submission].self, from: json)
        XCTAssertNil(subs.first?.score)
        XCTAssertEqual(subs.first?.workflowState, "unsubmitted")
    }

    func testCourseDecodesGradingScheme() throws {
        let json = """
        [{"id":1,"name":"CS 420","course_code":"CS 420","apply_assignment_group_weights":true,
          "grading_scheme":[["A",0.94],["A-",0.90],["F",0.0]]}]
        """.data(using: .utf8)!
        let courses = try decoder().decode([Course].self, from: json)
        let entry = try XCTUnwrap(courses.first?.gradingScheme?.first)
        XCTAssertEqual(entry.name, "A")
        XCTAssertEqual(entry.value, 0.94, accuracy: 0.001)
    }

    func testCourseDecodesSyllabusBody() throws {
        let json = """
        [{"id":1,"name":"CS 420","course_code":"CS 420","apply_assignment_group_weights":true,
          "syllabus_body":"<p>Welcome to the course</p>"}]
        """.data(using: .utf8)!
        let courses = try decoder().decode([Course].self, from: json)
        XCTAssertEqual(courses.first?.syllabusBody, "<p>Welcome to the course</p>")
    }

    func testAssignmentDecodesExtendedFields() throws {
        let json = """
        [{"id":100,"name":"HW1","points_possible":50.0,"due_at":null,"assignment_group_id":10,
          "description":"<p>Do the homework</p>",
          "submission_types":["online_upload","online_text_entry"],
          "unlock_at":"2026-01-01T00:00:00Z",
          "lock_at":"2026-01-31T23:59:00Z",
          "html_url":"https://canvas.example.com/courses/1/assignments/100",
          "rubric":[{"id":"1","description":"Content","points":10.0,
                     "ratings":[{"id":"r1","description":"Great","points":10.0}]}]}]
        """.data(using: .utf8)!
        let assignments = try decoder().decode([Assignment].self, from: json)
        let a = try XCTUnwrap(assignments.first)
        XCTAssertEqual(a.descriptionHTML, "<p>Do the homework</p>")
        XCTAssertEqual(a.submissionTypes, ["online_upload", "online_text_entry"])
        XCTAssertEqual(a.unlockAt, "2026-01-01T00:00:00Z")
        XCTAssertEqual(a.lockAt, "2026-01-31T23:59:00Z")
        XCTAssertEqual(a.htmlURL, "https://canvas.example.com/courses/1/assignments/100")
        XCTAssertEqual(a.rubric?.first?.description, "Content")
        XCTAssertEqual(a.rubric?.first?.ratings?.first?.description, "Great")
    }

    func testSubmissionDecodesExtendedFields() throws {
        let json = """
        [{"id":1,"user_id":1,"assignment_id":100,"score":8.0,"workflow_state":"graded",
          "late":true,"missing":false,"excused":false,"attempt":2,
          "rubric_assessment":{"1":{"points":8.0,"comments":"Good job","rating_id":"r1"}}}]
        """.data(using: .utf8)!
        let subs = try decoder().decode([Submission].self, from: json)
        let s = try XCTUnwrap(subs.first)
        XCTAssertEqual(s.late, true)
        XCTAssertEqual(s.missing, false)
        XCTAssertEqual(s.excused, false)
        XCTAssertEqual(s.attempt, 2)
        XCTAssertEqual(s.rubricAssessment?["1"]?.points, 8.0)
        XCTAssertEqual(s.rubricAssessment?["1"]?.comments, "Good job")
        XCTAssertEqual(s.rubricAssessment?["1"]?.ratingId, "r1")
    }

    func testAnnouncementDecodesNestedAuthor() throws {
        let json = """
        [{"id":5,"title":"Welcome","message":"<p>Hi class</p>","posted_at":"2026-01-01T00:00:00Z",
          "author":{"display_name":"Prof. Smith"}}]
        """.data(using: .utf8)!
        let announcements = try decoder().decode([Announcement].self, from: json)
        let a = try XCTUnwrap(announcements.first)
        XCTAssertEqual(a.title, "Welcome")
        XCTAssertEqual(a.postedAt, "2026-01-01T00:00:00Z")
        XCTAssertEqual(a.author?.displayName, "Prof. Smith")
    }
}
