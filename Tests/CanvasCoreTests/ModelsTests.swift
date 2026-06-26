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
        XCTAssertTrue(courses.first!.applyAssignmentGroupWeights)
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
        [{"assignment_id":100,"score":null,"workflow_state":"unsubmitted"}]
        """.data(using: .utf8)!
        let subs = try decoder().decode([Submission].self, from: json)
        XCTAssertNil(subs.first?.score)
        XCTAssertEqual(subs.first?.workflowState, "unsubmitted")
    }
}
