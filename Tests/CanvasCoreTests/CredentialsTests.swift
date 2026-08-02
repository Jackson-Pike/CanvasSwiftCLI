import XCTest
@testable import CanvasCore

final class CredentialsTests: XCTestCase {
    func testNormalizeHost() {
        XCTAssertEqual(Credentials.normalizeHost("byuh.instructure.com"), "byuh.instructure.com")
        XCTAssertEqual(Credentials.normalizeHost("  https://byuh.instructure.com/  "), "byuh.instructure.com")
        XCTAssertEqual(Credentials.normalizeHost("https://canvas.school.edu/api/v1"), "canvas.school.edu")
        XCTAssertEqual(Credentials.normalizeHost("HTTP://Canvas.School.EDU"), "canvas.school.edu")
        XCTAssertNil(Credentials.normalizeHost(""))
        XCTAssertNil(Credentials.normalizeHost("not a host name"))
        XCTAssertNil(Credentials.normalizeHost("https://"))
    }

    func testAPIClientBuildsURLsFromHost() async throws {
        // Reuse the PaginationStub pattern: a stub that records the request URL.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecordingStub.self]
        RecordingStub.lastURL = nil
        RecordingStub.body = Data("[]".utf8)
        let client = APIClient(
            credentials: Credentials(host: "canvas.other.edu", token: "T"),
            session: URLSession(configuration: config)
        )
        _ = try await client.courses()
        XCTAssertEqual(RecordingStub.lastURL?.host, "canvas.other.edu")
        XCTAssertEqual(RecordingStub.lastURL?.path, "/api/v1/courses")
    }
}

final class RecordingStub: URLProtocol {
    static var lastURL: URL?
    static var body = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastURL = request.url
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
