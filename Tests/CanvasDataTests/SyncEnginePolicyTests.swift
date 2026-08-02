import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class SyncEnginePolicyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SyncStub.reset()
    }

    // MARK: - TTL freshness gate

    func testTTLGateSkipsFreshData() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        try await engine.refresh(.all)
        let repo = await CanvasRepository(modelContainer: container)
        let first = try await repo.lastSyncedAt(entityKind: "courses", scopeId: "all")
        XCTAssertNotNil(first)

        try await Task.sleep(nanoseconds: 50_000_000)
        try await engine.refresh(.all)   // fresh — must skip the fetch
        let second = try await repo.lastSyncedAt(entityKind: "courses", scopeId: "all")
        XCTAssertEqual(first, second)
    }

    func testForceBypassesTTL() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        try await engine.refresh(.all)
        let repo = await CanvasRepository(modelContainer: container)
        let first = try await repo.lastSyncedAt(entityKind: "courses", scopeId: "all")
        XCTAssertNotNil(first)

        try await Task.sleep(nanoseconds: 50_000_000)
        try await engine.refresh(.all, force: true)
        let second = try await repo.lastSyncedAt(entityKind: "courses", scopeId: "all")
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Partial-failure isolation

    func testPartialFailureIsolation() async throws {
        let coursesBody = """
        [{"id":501,"name":"Course One","course_code":"C1","apply_assignment_group_weights":false,"grading_scheme":null},
         {"id":502,"name":"Course Two","course_code":"C2","apply_assignment_group_weights":false,"grading_scheme":null}]
        """
        SyncStub.responses["/api/v1/courses"] = [(200, Data(coursesBody.utf8), [:])]
        SyncStub.responses["/api/v1/courses/501/enrollments"] = [(200, Data("[{\"grades\":null}]".utf8), [:])]
        SyncStub.responses["/api/v1/courses/502/enrollments"] = [(500, Data("boom".utf8), [:])]

        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: stubbedClient())

        try await engine.refresh(.all)   // must not throw

        let repo = await CanvasRepository(modelContainer: container)
        let enrollment1 = try await repo.enrollment(courseId: 501)
        XCTAssertNotNil(enrollment1)

        let meta1Error: String? = try await MainActor.run {
            let ctx = repo.modelContainer.mainContext
            let key = "enrollments:501"
            let predicate = #Predicate<SyncMetadata> { $0.key == key }
            return try ctx.fetch(FetchDescriptor(predicate: predicate)).first?.lastErrorDescription
        }
        let meta2Error: String? = try await MainActor.run {
            let ctx = repo.modelContainer.mainContext
            let key = "enrollments:502"
            let predicate = #Predicate<SyncMetadata> { $0.key == key }
            return try ctx.fetch(FetchDescriptor(predicate: predicate)).first?.lastErrorDescription
        }
        XCTAssertNil(meta1Error)
        XCTAssertNotNil(meta2Error)
    }

    // MARK: - Rate-limit backoff

    func testRateLimitedRetriesOnceThenSucceeds() async throws {
        let coursesBody = """
        [{"id":601,"name":"Course One","course_code":"C1","apply_assignment_group_weights":false,"grading_scheme":null}]
        """
        SyncStub.responses["/api/v1/courses"] = [
            (403, Data("Rate Limit Exceeded".utf8), ["Retry-After": "0"]),
            (200, Data(coursesBody.utf8), [:]),
        ]
        SyncStub.responses["/api/v1/courses/601/enrollments"] = [(200, Data("[]".utf8), [:])]

        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: stubbedClient())

        try await engine.refresh(.all)   // must succeed after one retry

        XCTAssertEqual(SyncStub.hitCount["/api/v1/courses"], 2)

        let repo = await CanvasRepository(modelContainer: container)
        let courses = try await repo.courses()
        XCTAssertEqual(courses.count, 1)
    }

    // MARK: - Stub helpers

    private func stubbedClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SyncStub.self]
        return APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "test-token"),
                         session: URLSession(configuration: config))
    }
}
