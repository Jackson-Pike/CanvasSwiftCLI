import XCTest
@testable import CanvasCore

final class APIClientMessagingTests: XCTestCase {

    var session: URLSession!
    var client: APIClient!

    override func setUp() {
        super.setUp()
        PaginationStub.pages = [:]
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PaginationStub.self]
        session = URLSession(configuration: config)
        client = APIClient(token: "test-token", session: session)
    }

    func testCourseTeachersReturnsUserIds() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/5/enrollments?type%5B%5D=TeacherEnrollment&per_page=50"
        PaginationStub.pages[url] = (
            """
            [{"id":99,"user_id":42,"type":"TeacherEnrollment"},
             {"id":100,"user_id":43,"type":"TeacherEnrollment"}]
            """.data(using: .utf8)!,
            nil
        )

        let ids = try await client.courseTeachers(courseId: 5)
        XCTAssertEqual(ids, [42, 43])
    }

    func testCourseTeachersEmptyWhenNoTeachers() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/5/enrollments?type%5B%5D=TeacherEnrollment&per_page=50"
        PaginationStub.pages[url] = ("[]".data(using: .utf8)!, nil)

        let ids = try await client.courseTeachers(courseId: 5)
        XCTAssertEqual(ids, [])
    }
}
