import XCTest
import SwiftData
@testable import CanvasData

final class SchemaTests: XCTestCase {
    @MainActor
    func testInsertAndFetchEveryModel() throws {
        let container = try CanvasStore.container(inMemory: true)
        let ctx = container.mainContext
        ctx.insert(CachedCourse(id: 1, name: "BIOL 100", courseCode: "BIOL100",
                                applyGroupWeights: true, gradingSchemeJSON: nil, sortIndex: 0))
        ctx.insert(CachedEnrollment(courseId: 1, currentScore: 87.4, currentGrade: "B+"))
        ctx.insert(CachedAssignmentGroup(id: 10, courseId: 1, name: "Exams", groupWeight: 30,
                                         dropLowest: 0, dropHighest: 0, neverDrop: []))
        ctx.insert(CachedAssignment(id: 100, courseId: 1, groupId: 10, name: "Midterm",
                                    pointsPossible: 100, dueAt: .now, sortIndex: 0))
        ctx.insert(CachedSubmission(id: 1000, assignmentId: 100, courseId: 1, userId: 7,
                                    score: 92, workflowState: "graded", gradedAt: .now, submittedAt: nil))
        ctx.insert(CachedComment(id: 5, submissionId: 1000, assignmentId: 100,
                                 authorId: 8, authorName: "Prof", body: "Nice", createdAt: .now))
        ctx.insert(GradeSnapshot(courseId: 1, capturedAt: .now, percent: 87.4, letter: "B+"))
        ctx.insert(ChangeRecord(kind: .newGrade, courseId: 1, subjectId: 100,
                                title: "Midterm", detail: "92 / 100", occurredAt: .now))
        ctx.insert(SyncMetadata(entityKind: "submissions", scopeId: "1"))
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedCourse>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<ChangeRecord>()).first?.changeKind, .newGrade)
    }

    func testCanvasDateParsesISO8601() {
        XCTAssertNotNil(CanvasDate.parse("2026-08-01T12:00:00Z"))
        XCTAssertNotNil(CanvasDate.parse("2026-08-01T12:00:00.123Z"))
        XCTAssertNil(CanvasDate.parse(nil))
        XCTAssertNil(CanvasDate.parse("garbage"))
    }

    @MainActor
    func testGradingScaleFallsBackToBYUHDefault() throws {
        let course = CachedCourse(id: 2, name: "X", courseCode: "X",
                                  applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 0)
        XCTAssertEqual(course.gradingScale.first?.0, "A")
        let pairs = [SchemePair(name: "P", value: 0.5), SchemePair(name: "F", value: 0.0)]
        course.gradingSchemeJSON = try JSONEncoder().encode(pairs)
        XCTAssertEqual(course.gradingScale.map(\.0), ["P", "F"])
        XCTAssertEqual(course.gradingScale.first?.1 ?? 0, 50, accuracy: 0.001)
    }
}
