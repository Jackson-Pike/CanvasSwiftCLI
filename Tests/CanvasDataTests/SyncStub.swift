import Foundation

/// URLProtocol stub keyed by URL path, serving a queue of responses per path
/// (popped sequentially — call N to a path returns responses[path][N-1]).
/// Used for TTL-gate / rate-limit / partial-failure tests in SyncEnginePolicyTests.
final class SyncStub: URLProtocol {
    static var responses: [String: [(status: Int, body: Data, headers: [String: String])]] = [:]
    static var hitCount: [String: Int] = [:]

    static func reset() {
        responses = [:]
        hitCount = [:]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url!.path
        SyncStub.hitCount[path, default: 0] += 1
        guard var queue = SyncStub.responses[path], !queue.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let next = queue.removeFirst()
        SyncStub.responses[path] = queue
        var headers = next.headers
        headers["Content-Type"] = "application/json"
        let response = HTTPURLResponse(url: request.url!, statusCode: next.status,
                                       httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: next.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
