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
}
