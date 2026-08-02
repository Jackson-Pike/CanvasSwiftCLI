import XCTest
@testable import CanvasCore

final class ProfileTests: XCTestCase {
    private func client(stub: (Int, Data, [String: String])) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixedResponseStub.self]
        FixedResponseStub.status = stub.0
        FixedResponseStub.body = stub.1
        FixedResponseStub.headers = stub.2
        return APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "T"),
                         session: URLSession(configuration: config))
    }

    func testProfileDecodes() async throws {
        let json = Data(#"{"id": 42, "name": "Jackson Pike", "primary_email": "x@byuh.edu"}"#.utf8)
        let profile = try await client(stub: (200, json, [:])).profile()
        XCTAssertEqual(profile.id, 42)
        XCTAssertEqual(profile.name, "Jackson Pike")
        XCTAssertEqual(profile.primaryEmail, "x@byuh.edu")
    }

    func testDemoProfile() async throws {
        let profile = try await APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")).profile()
        XCTAssertEqual(profile.name, MockData.profile.name)
    }

    func testRateLimitedMapsToBackoffError() async throws {
        let body = Data("403 Forbidden (Rate Limit Exceeded)".utf8)
        do {
            _ = try await client(stub: (403, body, ["Retry-After": "7"])).profile()
            XCTFail("expected throw")
        } catch let APIError.rateLimited(retryAfter) {
            XCTAssertEqual(retryAfter, 7, accuracy: 0.01)
        }
    }

    func testPlainForbidden() async throws {
        do {
            _ = try await client(stub: (403, Data("nope".utf8), [:])).profile()
            XCTFail("expected throw")
        } catch APIError.forbidden {
            // pass
        }
    }

    func testSubmissionCommentDecodesId() throws {
        let json = Data(#"{"id": 9, "author_id": 1, "author_name": "T", "comment": "hi", "created_at": null}"#.utf8)
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        XCTAssertEqual(try d.decode(SubmissionComment.self, from: json).id, 9)
    }
}

final class FixedResponseStub: URLProtocol {
    static var status = 200
    static var body = Data()
    static var headers: [String: String] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var h = Self.headers; h["Content-Type"] = "application/json"
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                       httpVersion: nil, headerFields: h)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
