import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class SyncEngineCourseTests: XCTestCase {

    func testCourseSyncPopulatesGroupsAssignmentsSubmissionsComments() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        let courseId = MockData.csCourseId
        try await engine.refresh(.course(courseId))

        let repo = await CanvasRepository(modelContainer: container)
        let groups = try await repo.assignmentGroups(courseId: courseId)
        let expectedGroups = MockData.assignmentGroups[courseId] ?? []
        XCTAssertEqual(groups.count, expectedGroups.count)

        let assignments = try await repo.assignments(courseId: courseId)
        let expectedAssignments = expectedGroups.flatMap(\.assignments)
        XCTAssertEqual(assignments.count, expectedAssignments.count)

        let submissions = try await repo.submissions(courseId: courseId)
        let expectedSubmissions = MockData.submissions[courseId] ?? []
        XCTAssertEqual(submissions.count, expectedSubmissions.count)

        let weekOne = assignments.first { $0.id == 201 }
        XCTAssertNotNil(weekOne?.dueAt)

        let comments = try await repo.comments(assignmentId: 201)
        XCTAssertEqual(comments.count, 1)
        let noComments = try await repo.comments(assignmentId: 202)
        XCTAssertEqual(noComments.count, 0)
    }

    func testCourseResyncIsIdempotentAndBaselineSilent() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        let courseId = MockData.csCourseId
        try await engine.refresh(.course(courseId))
        try await engine.refresh(.course(courseId), force: true)

        let repo = await CanvasRepository(modelContainer: container)
        let assignments = try await repo.assignments(courseId: courseId)
        let expectedAssignments = (MockData.assignmentGroups[courseId] ?? []).flatMap(\.assignments)
        XCTAssertEqual(assignments.count, expectedAssignments.count)

        let submissions = try await repo.submissions(courseId: courseId)
        let expectedSubmissions = MockData.submissions[courseId] ?? []
        XCTAssertEqual(submissions.count, expectedSubmissions.count)

        let changes = try await repo.changes(since: Date.distantPast)
        XCTAssertEqual(changes.count, 0)
    }

    func testGradeTransitionEmitsNewGradeRecord() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        let courseId = MockData.csCourseId
        try await engine.refresh(.course(courseId))

        let repo = await CanvasRepository(modelContainer: container)
        try await MainActor.run {
            let ctx = repo.modelContainer.mainContext
            let predicate = #Predicate<CachedSubmission> { $0.assignmentId == 201 }
            let submission = try ctx.fetch(FetchDescriptor(predicate: predicate)).first
            XCTAssertNotNil(submission)
            submission?.score = nil
            try ctx.save()
        }

        try await engine.refresh(.course(courseId), force: true)

        let changes = try await repo.changes(since: Date.distantPast)
        let newGradeChanges = changes.filter { $0.changeKind == .newGrade && $0.subjectId == 201 }
        XCTAssertEqual(newGradeChanges.count, 1)
    }

    func testMutedGradeNeverEmitsNewGrade() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        let courseId = MockData.csCourseId
        let mutedAssignmentId = 402   // Final Exam — muted grade fixture (workflowState graded, score nil)

        try await engine.refresh(.course(courseId))
        try await engine.refresh(.course(courseId), force: true)

        let repo = await CanvasRepository(modelContainer: container)
        let changes = try await repo.changes(since: Date.distantPast)
        let mutedNewGradeChanges = changes.filter {
            $0.changeKind == .newGrade && $0.subjectId == mutedAssignmentId
        }
        XCTAssertEqual(mutedNewGradeChanges.count, 0)
    }

    func testAssignmentMissingFromFetchIsSoftDeleted() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        let courseId = MockData.csCourseId
        try await engine.refresh(.course(courseId))

        let repo = await CanvasRepository(modelContainer: container)
        try await MainActor.run {
            let ctx = repo.modelContainer.mainContext
            ctx.insert(CachedAssignment(id: 555555, courseId: courseId, groupId: 1001,
                                         name: "Ghost Assignment", pointsPossible: 10,
                                         dueAt: nil, sortIndex: 999))
            try ctx.save()
        }

        try await engine.refresh(.course(courseId), force: true)

        let ghostRemovedAt: Date? = try await MainActor.run {
            let ctx = repo.modelContainer.mainContext
            let predicate = #Predicate<CachedAssignment> { $0.id == 555555 }
            return try ctx.fetch(FetchDescriptor(predicate: predicate)).first?.removedAt
        }
        XCTAssertNotNil(ghostRemovedAt)
    }

    // MARK: - Partial vs. total failure (spec §2.5)

    /// Only groups succeed (with a legitimately empty result) while submissions 500s.
    /// refresh must NOT throw: a successful-but-empty fetch is not the same as a failed one.
    func testPartialFailureWithLegitimatelyEmptyGroupsDoesNotThrow() async throws {
        let courseId = 777001
        RouteStub.routes = [
            groupsURL(courseId): (200, Data("[]".utf8), [:]),
            submissionsURL(courseId): (500, Data("boom".utf8), [:]),
        ]
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: stubbedClient())

        try await engine.refresh(.course(courseId))   // must not throw

        let repo = await CanvasRepository(modelContainer: container)
        let groups = try await repo.assignmentGroups(courseId: courseId)
        XCTAssertEqual(groups.count, 0)   // legitimately empty, not "missing"

        let groupsSyncedAt = try await repo.lastSyncedAt(entityKind: "assignments", scopeId: "\(courseId)")
        XCTAssertNotNil(groupsSyncedAt)   // groups succeeded and recorded a sync time
    }

    /// Both groups and submissions fail: refresh must throw (spec: "throw only if everything failed").
    func testBothFetchesFailingThrows() async throws {
        let courseId = 777002
        RouteStub.routes = [
            groupsURL(courseId): (500, Data("boom".utf8), [:]),
            submissionsURL(courseId): (500, Data("boom".utf8), [:]),
        ]
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: stubbedClient())

        do {
            try await engine.refresh(.course(courseId))
            XCTFail("expected throw when both fetches fail")
        } catch {
            // expected
        }
    }

    /// dueSoon baseline suppression must key off "was there ever a prior submissions sync",
    /// not "are there zero cached submissions right now" — a course can legitimately have
    /// zero submissions on every sync (e.g. nothing assigned yet) and still need dueSoon
    /// notifications to fire starting on its second sync.
    func testDueSoonFiresOnSecondSyncEvenWithZeroCachedSubmissions() async throws {
        let courseId = 777003
        let assignmentId = 9002
        let dueAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let groupsBody = """
        [{"id":9001,"name":"G1","group_weight":100,"rules":null,
          "assignments":[{"id":\(assignmentId),"name":"Quiz","points_possible":10,
                          "due_at":"\(dueAt)","assignment_group_id":9001}]}]
        """
        RouteStub.routes = [
            groupsURL(courseId): (200, Data(groupsBody.utf8), [:]),
            submissionsURL(courseId): (200, Data("[]".utf8), [:]),
        ]
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: stubbedClient())

        try await engine.refresh(.course(courseId))   // baseline: no dueSoon yet
        let repo = await CanvasRepository(modelContainer: container)
        let baselineChanges = try await repo.changes(since: Date.distantPast)
        XCTAssertEqual(baselineChanges.filter { $0.changeKind == .dueSoon }.count, 0)

        try await engine.refresh(.course(courseId), force: true)   // still zero submissions fetched
        let secondChanges = try await repo.changes(since: Date.distantPast)
        let dueSoon = secondChanges.filter { $0.changeKind == .dueSoon && $0.subjectId == assignmentId }
        XCTAssertEqual(dueSoon.count, 1)
    }

    // MARK: - Stub helpers

    private func groupsURL(_ courseId: Int) -> String {
        "https://byuh.instructure.com/api/v1/courses/\(courseId)/assignment_groups?include%5B%5D=assignments&include%5B%5D=rubric&per_page=100"
    }

    private func submissionsURL(_ courseId: Int) -> String {
        "https://byuh.instructure.com/api/v1/courses/\(courseId)/students/submissions?student_ids%5B%5D=self&include%5B%5D=submission_comments&include%5B%5D=rubric_assessment&per_page=100"
    }

    private func stubbedClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RouteStub.self]
        return APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "test-token"),
                         session: URLSession(configuration: config))
    }
}

/// URLProtocol stub keyed by exact URL string → (status, body, headers).
final class RouteStub: URLProtocol {
    static var routes: [String: (Int, Data, [String: String])] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let key = request.url!.absoluteString
        guard let (status, body, headers) = RouteStub.routes[key] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        var h = headers; h["Content-Type"] = "application/json"
        let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: h)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
