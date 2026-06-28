import XCTest
@testable import CanvasCore

#if DEBUG
final class APIClientDemoTests: XCTestCase {

    private let demo = APIClient(token: "DEMO")

    func testCoursesReturnsMockCourse() async throws {
        let courses = try await demo.courses()
        XCTAssertEqual(courses.count, 1)
        XCTAssertEqual(courses[0].id, MockData.courseId)
        XCTAssertEqual(courses[0].name, "Intro to Software Engineering")
    }

    func testEnrollmentsReturnsMockEnrollment() async throws {
        let enrollments = try await demo.enrollments(courseId: MockData.courseId)
        XCTAssertEqual(enrollments.count, 1)
        XCTAssertEqual(enrollments[0].grades?.currentScore, 87.2)
    }

    func testAssignmentGroupsReturnsMockGroups() async throws {
        let groups = try await demo.assignmentGroups(courseId: MockData.courseId)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups.map { $0.groupWeight }.reduce(0, +), 100.0, accuracy: 0.001)
    }

    func testSubmissionsReturnsMockSubmissions() async throws {
        let subs = try await demo.submissions(courseId: MockData.courseId)
        XCTAssertEqual(subs.count, 8)
        let awaiting = subs.filter { $0.workflowState == "submitted" && $0.score == nil }
        XCTAssertEqual(awaiting.count, 1)
    }

    func testCourseTeachersReturnsMockTeacherIds() async throws {
        let ids = try await demo.courseTeachers(courseId: MockData.courseId)
        XCTAssertEqual(ids, [MockData.teacherUserId])
    }
}
#endif
