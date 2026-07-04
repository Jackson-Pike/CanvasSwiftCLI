# Canvas API Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all Canvas API fetches follow HTTP `Link` headers so that courses with >100 assignments or submissions return complete data rather than silently truncating.

**Architecture:** Add a `getPaginated` method to `APIClient` that collects all pages by following the `rel="next"` URL from the `Link` response header. All four public endpoints that currently call `get(_:query:)` are updated to call `getPaginated` instead and concatenate their results. No new public types are introduced.

**Tech Stack:** Swift, Foundation (`URLSession`, `URLComponents`, `URLResponse`), XCTest

## Global Constraints

- Swift tools version: 5.9, platform: macOS 14
- No new package dependencies
- All existing tests must continue to pass
- Test framework: XCTest (existing suite uses XCTest — keep new tests consistent)

---

### Task 1: Implement `getPaginated` and update all endpoints

**Files:**
- Modify: `Sources/CanvasCore/APIClient.swift`
- Create: `Tests/CanvasCoreTests/APIClientPaginationTests.swift`

**Interfaces:**
- Produces: `private func getPaginated(_ path: String, query: [URLQueryItem]) async throws -> Data` — fetches all pages, returns combined JSON array `Data`
- All four public methods (`courses`, `enrollments`, `assignmentGroups`, `submissions`) switch from `get` to `getPaginated`

- [ ] **Step 1: Write the failing pagination test**

Create `Tests/CanvasCoreTests/APIClientPaginationTests.swift`:

```swift
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
        let p1 = "\(base)/courses?enrollment_state=active&per_page=50&include%5B%5D=grading_scheme"
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/kahuku-air/Developer/CanvasCLISwift
swift test --filter APIClientPaginationTests 2>&1 | tail -20
```

Expected: compile error — `APIClient` has no `init(token:session:)` parameter, and `getPaginated` doesn't exist yet.

- [ ] **Step 3: Update `APIClient` to support an injected `URLSession` and implement `getPaginated`**

Replace the entire contents of `Sources/CanvasCore/APIClient.swift` with:

```swift
import Foundation

public enum APIError: Error, CustomStringConvertible {
    case missingToken
    case unauthorized
    case http(Int)
    case network(String)

    public var description: String {
        switch self {
        case .missingToken:     return "CANVAS_TOKEN is not set."
        case .unauthorized:     return "Invalid token — update in Settings."
        case .http(let code):   return "Canvas API returned HTTP \(code)."
        case .network(let msg): return "Network error: \(msg)."
        }
    }
}

public struct APIClient {
    let token: String
    private let baseURL = "https://byuh.instructure.com/api/v1"
    private let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    // Fetches a single page; returns (body, nextURL)
    private func getPage(url: URL) async throws -> (Data, URL?) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 { throw APIError.unauthorized }
                guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
                let nextURL = Self.nextPageURL(from: http)
                return (data, nextURL)
            }
            return (data, nil)
        } catch let error as APIError { throw error }
        catch { throw APIError.network(error.localizedDescription) }
    }

    // Parses the `Link: <url>; rel="next"` header
    private static func nextPageURL(from response: HTTPURLResponse) -> URL? {
        guard let link = response.value(forHTTPHeaderField: "Link") else { return nil }
        // Link header can contain multiple entries separated by ", "
        for part in link.components(separatedBy: ",") {
            let segments = part.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard segments.count >= 2 else { continue }
            let isNext = segments.dropFirst().contains(where: { $0 == "rel=\"next\"" })
            guard isNext else { continue }
            // Extract URL from angle brackets: <https://...>
            let urlPart = segments[0]
            guard urlPart.hasPrefix("<"), urlPart.hasSuffix(">") else { continue }
            let urlString = String(urlPart.dropFirst().dropLast())
            return URL(string: urlString)
        }
        return nil
    }

    // Follows Link pages and returns a single JSON array combining all pages
    private func getPaginated(_ path: String, query: [URLQueryItem]) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.network("bad URL \(path)")
        }
        components.queryItems = query
        guard let firstURL = components.url else { throw APIError.network("bad query for \(path)") }

        var allItems: [[String: Any]] = []
        var nextURL: URL? = firstURL

        while let currentURL = nextURL {
            let (pageData, pageNext) = try await getPage(url: currentURL)
            if let pageItems = try JSONSerialization.jsonObject(with: pageData) as? [[String: Any]] {
                allItems.append(contentsOf: pageItems)
            }
            nextURL = pageNext
        }

        return try JSONSerialization.data(withJSONObject: allItems)
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    public func courses() async throws -> [Course] {
        let data = try await getPaginated("/courses", query: [
            URLQueryItem(name: "enrollment_state", value: "active"),
            URLQueryItem(name: "per_page", value: "50"),
            URLQueryItem(name: "include[]", value: "grading_scheme")
        ])
        return try decoder().decode([Course].self, from: data)
    }

    public func enrollments(courseId: Int) async throws -> [Enrollment] {
        let data = try await getPaginated("/courses/\(courseId)/enrollments", query: [
            URLQueryItem(name: "user_id", value: "self"),
            URLQueryItem(name: "include[]", value: "grades")
        ])
        return try decoder().decode([Enrollment].self, from: data)
    }

    public func assignmentGroups(courseId: Int) async throws -> [AssignmentGroup] {
        let data = try await getPaginated("/courses/\(courseId)/assignment_groups", query: [
            URLQueryItem(name: "include[]", value: "assignments"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([AssignmentGroup].self, from: data)
    }

    public func submissions(courseId: Int) async throws -> [Submission] {
        let data = try await getPaginated("/courses/\(courseId)/students/submissions", query: [
            URLQueryItem(name: "student_ids[]", value: "self"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([Submission].self, from: data)
    }
}
```

- [ ] **Step 4: Run all tests**

```bash
swift test 2>&1 | tail -30
```

Expected: All tests pass — existing `ModelsTests`, `GradeCalculatorTests`, `SolverTests`, and the new `APIClientPaginationTests`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/APIClient.swift Tests/CanvasCoreTests/APIClientPaginationTests.swift
git commit -m "feat: follow Link header pagination in all Canvas API endpoints

All four public endpoints (courses, enrollments, assignmentGroups,
submissions) now follow rel=next Link headers to collect every page.
URLSession is injected for testability; URLProtocol stub drives tests
without network access."
```
