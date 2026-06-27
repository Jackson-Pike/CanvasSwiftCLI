import XCTest
@testable import CanvasCore

// URLProtocol stub that serves paginated Canvas-style responses
final class PaginationStub: URLProtocol {
    // Map of URL string → (body: Data, nextURL: String?)
    static var pages: [String: (Data, String?)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let key = request.url!.absoluteString
        guard let (body, nextURL) = PaginationStub.pages[key] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        var headers: [String: String] = ["Content-Type": "application/json"]
        if let next = nextURL {
            headers["Link"] = "<\(next)>; rel=\"next\""
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class APIClientPaginationTests: XCTestCase {

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

    // Two pages of submissions — result must contain items from both pages
    func testSubmissionsPaginatesAcrossMultiplePages() async throws {
        let page1URL = "https://byuh.instructure.com/api/v1/courses/42/students/submissions?student_ids%5B%5D=self&per_page=100"
        let page2URL = "https://byuh.instructure.com/api/v1/courses/42/students/submissions?page=2&per_page=100"

        PaginationStub.pages[page1URL] = (
            """
            [{"id":1,"assignment_id":10,"score":85.0,"workflow_state":"graded"}]
            """.data(using: .utf8)!,
            page2URL
        )
        PaginationStub.pages[page2URL] = (
            """
            [{"id":2,"assignment_id":11,"score":90.0,"workflow_state":"graded"}]
            """.data(using: .utf8)!,
            nil
        )

        let submissions = try await client.submissions(courseId: 42)
        XCTAssertEqual(submissions.count, 2)
        XCTAssertEqual(submissions[0].id, 1)
        XCTAssertEqual(submissions[1].id, 2)
    }

    // Single page — must not loop
    func testSinglePageReturnsCorrectly() async throws {
        let pageURL = "https://byuh.instructure.com/api/v1/courses/7/students/submissions?student_ids%5B%5D=self&per_page=100"
        PaginationStub.pages[pageURL] = (
            """
            [{"id":99,"assignment_id":5,"score":70.0,"workflow_state":"graded"}]
            """.data(using: .utf8)!,
            nil
        )

        let submissions = try await client.submissions(courseId: 7)
        XCTAssertEqual(submissions.count, 1)
        XCTAssertEqual(submissions[0].id, 99)
    }

    // Three pages of courses
    func testCoursesPaginatesThreePages() async throws {
        let base = "https://byuh.instructure.com/api/v1"
        let p1 = "\(base)/courses?enrollment_state=active&enrollment_type%5B%5D=student&per_page=50&include%5B%5D=grading_scheme"
        let p2 = "\(base)/courses?page=2&per_page=50"
        let p3 = "\(base)/courses?page=3&per_page=50"

        PaginationStub.pages[p1] = (
            """
            [{"id":1,"name":"Math","course_code":"MATH 101","apply_assignment_group_weights":false}]
            """.data(using: .utf8)!, p2
        )
        PaginationStub.pages[p2] = (
            """
            [{"id":2,"name":"CS","course_code":"CS 246","apply_assignment_group_weights":true}]
            """.data(using: .utf8)!, p3
        )
        PaginationStub.pages[p3] = (
            """
            [{"id":3,"name":"English","course_code":"ENG 201","apply_assignment_group_weights":false}]
            """.data(using: .utf8)!, nil
        )

        let courses = try await client.courses()
        XCTAssertEqual(courses.count, 3)
        XCTAssertEqual(courses.map(\.id), [1, 2, 3])
    }
}
