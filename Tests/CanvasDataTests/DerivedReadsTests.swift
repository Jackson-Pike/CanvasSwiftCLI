import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class DerivedReadsTests: XCTestCase {

    private func makeRepo() async throws -> (CanvasRepository, SyncEngine) {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)
        let repo = await CanvasRepository(modelContainer: container)
        return (repo, engine)
    }

    func testCalculatorInputsMatchBuildGradedItems() async throws {
        let (repo, engine) = try await makeRepo()
        let courseId = MockData.csCourseId

        try await engine.refresh(.all)
        try await engine.refresh(.course(courseId))

        let expectedGroups = MockData.assignmentGroups[courseId] ?? []
        let expectedSubmissions = MockData.submissions[courseId] ?? []
        let expected = buildGradedItems(groups: expectedGroups, submissions: expectedSubmissions)

        let inputs = try await repo.calculatorInputs(courseId: courseId)
        XCTAssertNotNil(inputs)
        let actual = inputs!.items

        XCTAssertEqual(actual.count, expected.count)
        let expectedById = Dictionary(uniqueKeysWithValues: expected.map { ($0.assignmentId, $0) })
        for item in actual {
            guard let match = expectedById[item.assignmentId] else {
                XCTFail("unexpected assignmentId \(item.assignmentId)")
                continue
            }
            XCTAssertEqual(item.name, match.name)
            XCTAssertEqual(item.groupId, match.groupId)
            XCTAssertEqual(item.pointsPossible, match.pointsPossible)
            XCTAssertEqual(item.earnedPoints, match.earnedPoints)
        }

        // Group rules: MockData has no drop rules anywhere, so every group defaults to 0/0/[]
        for group in expectedGroups {
            let info = inputs!.groups[group.id]
            XCTAssertNotNil(info)
            XCTAssertEqual(info?.name, group.name)
            XCTAssertEqual(info?.weight, group.groupWeight)
            XCTAssertEqual(info?.dropLowest, 0)
            XCTAssertEqual(info?.dropHighest, 0)
            XCTAssertEqual(info?.neverDrop, Set<Int>())
        }

        XCTAssertEqual(inputs!.weighted, true) // CS course applyAssignmentGroupWeights == true
    }

    func testCalculatorInputsReturnsNilForUnknownCourse() async throws {
        let (repo, engine) = try await makeRepo()
        try await engine.refresh(.all)

        let inputs = try await repo.calculatorInputs(courseId: 424242)
        XCTAssertNil(inputs)
    }

    func testStreamRulesOverCache() async throws {
        let (repo, engine) = try await makeRepo()
        let courseId = MockData.csCourseId

        try await engine.refresh(.all)
        try await engine.refresh(.course(courseId))

        // Shape three additional scenarios directly on the cached rows so every stream
        // rule (upcoming cap/order, feedback cap/order/self-exclusion) is exercised,
        // without disturbing the muted-grade (402) / awaiting-grade (303) fixtures or
        // the naturally-highest recentlyGraded candidates (401, 302).
        try await MainActor.run {
            let ctx = repo.modelContainer.mainContext

            // Turn 202/203/204 into future-due, unsubmitted assignments (soonest: 204, 203, 202).
            func makeUpcoming(assignmentId: Int, dueOffsetDays: Double) throws {
                let aPredicate = #Predicate<CachedAssignment> { $0.id == assignmentId }
                let assignment = try ctx.fetch(FetchDescriptor(predicate: aPredicate)).first
                assignment?.dueAt = Date().addingTimeInterval(dueOffsetDays * 86400)

                let sPredicate = #Predicate<CachedSubmission> { $0.assignmentId == assignmentId }
                let submission = try ctx.fetch(FetchDescriptor(predicate: sPredicate)).first
                submission?.workflowState = "unsubmitted"
                submission?.score = nil
                submission?.gradedAt = nil
            }
            try makeUpcoming(assignmentId: 204, dueOffsetDays: 1)
            try makeUpcoming(assignmentId: 203, dueOffsetDays: 2)
            try makeUpcoming(assignmentId: 202, dueOffsetDays: 3)

            // Give submission 1001 (assignment 201) extra teacher comments plus one
            // self-authored (student) comment that must be excluded regardless of recency.
            let commentA = CachedComment(id: 9101, submissionId: 1001, assignmentId: 201,
                                         authorId: MockData.teacherUserId, authorName: "Prof. Demo",
                                         body: "Comment A", createdAt: iso("2026-01-17T10:00:00Z"))
            let commentB = CachedComment(id: 9102, submissionId: 1001, assignmentId: 201,
                                         authorId: MockData.teacherUserId, authorName: "Prof. Demo",
                                         body: "Comment B", createdAt: iso("2026-01-18T10:00:00Z"))
            let commentC = CachedComment(id: 9103, submissionId: 1001, assignmentId: 201,
                                         authorId: MockData.teacherUserId, authorName: "Prof. Demo",
                                         body: "Comment C", createdAt: iso("2026-01-19T10:00:00Z"))
            let selfComment = CachedComment(id: 9104, submissionId: 1001, assignmentId: 201,
                                            authorId: MockData.studentUserId, authorName: "Demo Student",
                                            body: "Self comment", createdAt: iso("2026-01-20T10:00:00Z"))
            ctx.insert(commentA); ctx.insert(commentB); ctx.insert(commentC); ctx.insert(selfComment)
            try ctx.save()
        }

        let stream = try await repo.stream(courseId: courseId)

        func items(_ kind: (StreamItem.Kind) -> Bool) -> [StreamItem] {
            stream.filter { kind($0.kind) }
        }

        // Awaiting grade: submitted (303) + muted graded (402), capped at 2.
        let awaiting = items { if case .awaitingGrade = $0 { return true }; return false }
        XCTAssertEqual(awaiting.count, 2)
        XCTAssertEqual(Set(awaiting.map(\.assignment.id)), Set([303, 402]))

        // Upcoming: soonest-first, max 2 of the 3 candidates (204, 203, 202).
        let upcoming = items { if case .upcoming = $0 { return true }; return false }
        XCTAssertEqual(upcoming.map(\.assignment.id), [204, 203])

        // Recently graded: newest gradedAt first, max 2 -> Midterm (401), Quiz 2 (302).
        let recentlyGraded = items { if case .recentlyGraded = $0 { return true }; return false }
        XCTAssertEqual(recentlyGraded.map(\.assignment.id), [401, 302])
        for item in recentlyGraded {
            if case .recentlyGraded(let score, _, _) = item.kind {
                XCTAssertNotNil(score)
            }
        }

        // Feedback: newest first, max 3, self-authored comment excluded despite being newest.
        let feedback = items { if case .feedback = $0 { return true }; return false }
        XCTAssertEqual(feedback.count, 3)
        let feedbackBodies = feedback.compactMap { item -> String? in
            if case .feedback(_, let comment, _) = item.kind { return comment }
            return nil
        }
        XCTAssertEqual(feedbackBodies, ["Comment C", "Comment B", "Comment A"])
    }

    private func iso(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}
