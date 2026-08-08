import XCTest
@testable import CanvasCore

final class ConversationAPITests: XCTestCase {
    private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FormRecordingStub.self]
        FormRecordingStub.reset()
        return APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "T"),
                         session: URLSession(configuration: config))
    }

    func testConversationsUsesScopeQuery() async throws {
        FormRecordingStub.body = Data("[]".utf8)
        _ = try await client().conversations(scope: .unread)
        XCTAssertTrue(FormRecordingStub.lastURL!.absoluteString.contains("/conversations"))
        XCTAssertTrue(FormRecordingStub.lastURL!.absoluteString.contains("scope=unread"))
    }

    func testReplyPostsBodyForm() async throws {
        FormRecordingStub.body = Data(#"{"id":5,"workflow_state":"read"}"#.utf8)
        _ = try await client().replyToConversation(id: 5, body: "Thanks!")
        XCTAssertEqual(FormRecordingStub.lastMethod, "POST")
        XCTAssertTrue(FormRecordingStub.lastURL!.absoluteString.hasSuffix("/conversations/5/add_message"))
        let form = String(data: FormRecordingStub.lastBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(form.contains("body=Thanks%21"))
    }

    func testMarkReadPutsWorkflowState() async throws {
        FormRecordingStub.body = Data(#"{"id":5,"workflow_state":"read"}"#.utf8)
        try await client().markConversationRead(id: 5)
        XCTAssertEqual(FormRecordingStub.lastMethod, "PUT")
        let form = String(data: FormRecordingStub.lastBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(form.contains("conversation%5Bworkflow_state%5D=read"))  // conversation[workflow_state]=read
    }

    func testComposePostsRecipientsAndSubject() async throws {
        FormRecordingStub.body = Data(#"[{"id":9,"workflow_state":"read","subject":"Q"}]"#.utf8)
        let c = try await client().createConversation(recipientIds: [1, 2], subject: "Q", body: "Hello")
        XCTAssertEqual(c.id, 9)   // Canvas returns an array; we take the first
        let form = String(data: FormRecordingStub.lastBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(form.contains("recipients%5B%5D=1"))
        XCTAssertTrue(form.contains("recipients%5B%5D=2"))
        XCTAssertTrue(form.contains("subject=Q"))
        XCTAssertTrue(form.contains("body=Hello"))
    }

    func testDemoConversationsShortCircuit() async throws {
        let demo = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        let list = try await demo.conversations(scope: .inbox)
        XCTAssertFalse(list.isEmpty)
    }
}

final class FormRecordingStub: URLProtocol {
    static var body = Data()
    static var lastURL: URL?
    static var lastMethod: String?
    static var lastBody: Data?
    static func reset() { lastURL = nil; lastMethod = nil; lastBody = nil }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastURL = request.url
        Self.lastMethod = request.httpMethod
        // URLProtocol strips httpBody into a stream for non-GET; capture whichever is set.
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map(Self.drain)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    private static func drain(_ stream: InputStream) -> Data {
        stream.open(); defer { stream.close() }
        var data = Data(); let size = 4096; var buf = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buf, maxLength: size)
            if read <= 0 { break }
            data.append(buf, count: read)
        }
        return data
    }
}
