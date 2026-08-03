import XCTest
@testable import CanvasCore

#if DEBUG
final class APIClientDemoTests: XCTestCase {

    private let demo = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))

    func testCoursesReturnsMockCourses() async throws {
        let courses = try await demo.courses()
        XCTAssertEqual(courses.count, 4)
        XCTAssertTrue(courses.contains { $0.id == MockData.csCourseId && $0.name == "Intro to Software Engineering" })
    }

    func testEnrollmentsReturnsMockEnrollment() async throws {
        let enrollments = try await demo.enrollments(courseId: MockData.csCourseId)
        XCTAssertEqual(enrollments.count, 1)
        XCTAssertEqual(enrollments[0].grades?.currentScore, 87.2)
    }

    func testAssignmentGroupsReturnsMockGroups() async throws {
        let groups = try await demo.assignmentGroups(courseId: MockData.csCourseId)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups.map { $0.groupWeight }.reduce(0, +), 100.0, accuracy: 0.001)
    }

    func testSubmissionsReturnsMockSubmissions() async throws {
        let subs = try await demo.submissions(courseId: MockData.csCourseId)
        XCTAssertEqual(subs.count, 9)
        let awaiting = subs.filter { $0.workflowState == "submitted" && $0.score == nil }
        XCTAssertEqual(awaiting.count, 1)
    }

    func testCourseTeachersReturnsMockTeacherIds() async throws {
        let ids = try await demo.courseTeachers(courseId: MockData.csCourseId)
        XCTAssertEqual(ids, [MockData.teacherUserId])
    }

    func testDemoAnnouncementsReturnsMockData() async throws {
        let announcements = try await demo.announcements(courseId: MockData.csCourseId)
        let expected = MockData.announcements[MockData.csCourseId] ?? []
        XCTAssertEqual(announcements.count, 2)
        XCTAssertEqual(announcements.map { $0.id }, expected.map { $0.id })
        XCTAssertEqual(announcements.map { $0.title }, expected.map { $0.title })
    }
}
#endif
