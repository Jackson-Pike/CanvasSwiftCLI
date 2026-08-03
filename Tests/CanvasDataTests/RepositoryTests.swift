import XCTest
import SwiftData
@testable import CanvasData

final class RepositoryTests: XCTestCase {
    @MainActor
    func testCoursesSortPinnedFirstThenSortIndexAndExcludeHiddenAndRemoved() throws {
        let repo = CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))
        let ctx = repo.modelContainer.mainContext

        let a = CachedCourse(id: 1, name: "A Course", courseCode: "A100",
                              applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 1)
        let b = CachedCourse(id: 2, name: "B Course", courseCode: "B100",
                              applyGroupWeights: false, gradingSchemeJSON: nil, pinned: true, sortIndex: 0)
        let c = CachedCourse(id: 3, name: "C Course", courseCode: "C100",
                              applyGroupWeights: false, gradingSchemeJSON: nil, hidden: true, sortIndex: 2)
        let d = CachedCourse(id: 4, name: "D Course", courseCode: "D100",
                              applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 3,
                              removedAt: .now)
        ctx.insert(a); ctx.insert(b); ctx.insert(c); ctx.insert(d)
        try ctx.save()

        let visible = try repo.courses()
        XCTAssertEqual(visible.map(\.id), [2, 1])

        let withHidden = try repo.courses(includeHidden: true)
        XCTAssertEqual(withHidden.map(\.id), [2, 1, 3])
    }

    @MainActor
    func testSetHiddenAndSetPinnedPersist() throws {
        let repo = CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))
        let ctx = repo.modelContainer.mainContext
        let course = CachedCourse(id: 1, name: "Course", courseCode: "C100",
                                   applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 0)
        ctx.insert(course)
        try ctx.save()

        try repo.setHidden(true, courseId: 1)
        XCTAssertEqual(try repo.course(id: 1)?.hidden, true)

        try repo.setPinned(true, courseId: 1)
        XCTAssertEqual(try repo.course(id: 1)?.pinned, true)

        // Unknown id should not throw.
        XCTAssertNoThrow(try repo.setHidden(true, courseId: 999))
        XCTAssertNoThrow(try repo.setPinned(true, courseId: 999))
    }

    @MainActor
    func testUnseenChangesAndMarkSeen() throws {
        let repo = CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))
        let ctx = repo.modelContainer.mainContext

        let earlier = ChangeRecord(kind: .newGrade, courseId: 1, subjectId: 100,
                                    title: "Older", detail: nil,
                                    occurredAt: Date(timeIntervalSinceNow: -100))
        let later = ChangeRecord(kind: .newGrade, courseId: 1, subjectId: 101,
                                  title: "Newer", detail: nil,
                                  occurredAt: Date(timeIntervalSinceNow: -10))
        let seen = ChangeRecord(kind: .newGrade, courseId: 1, subjectId: 102,
                                 title: "Seen", detail: nil,
                                 occurredAt: Date(timeIntervalSinceNow: -50), seenAt: .now)
        ctx.insert(earlier); ctx.insert(later); ctx.insert(seen)
        try ctx.save()

        let unseen = try repo.unseenChanges()
        XCTAssertEqual(unseen.count, 2)
        XCTAssertEqual(unseen.map(\.title), ["Newer", "Older"])

        try repo.markChangesSeen()
        XCTAssertEqual(try repo.unseenChanges().count, 0)
    }

    @MainActor
    func testAnnouncementsSortedByPostedAtDescendingAndExcludeRemoved() throws {
        let repo = CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))
        let ctx = repo.modelContainer.mainContext
        let now = Date()

        ctx.insert(CachedAnnouncement(id: 1, courseId: 1, title: "Oldest", message: nil,
                                      postedAt: now.addingTimeInterval(-300), authorName: "Prof"))
        ctx.insert(CachedAnnouncement(id: 2, courseId: 1, title: "Newest", message: nil,
                                      postedAt: now.addingTimeInterval(-10), authorName: "Prof"))
        ctx.insert(CachedAnnouncement(id: 3, courseId: 1, title: "Middle", message: nil,
                                      postedAt: now.addingTimeInterval(-100), authorName: "Prof"))
        ctx.insert(CachedAnnouncement(id: 4, courseId: 1, title: "Removed", message: nil,
                                      postedAt: now, authorName: "Prof", removedAt: now))
        ctx.insert(CachedAnnouncement(id: 5, courseId: 2, title: "Other course", message: nil,
                                      postedAt: now, authorName: "Prof"))
        try ctx.save()

        let fetched = try repo.announcements(courseId: 1)
        XCTAssertEqual(fetched.map(\.title), ["Newest", "Middle", "Oldest"])
    }

    @MainActor
    func testMarkAnnouncementReadIsIdempotent() throws {
        let repo = CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))
        let ctx = repo.modelContainer.mainContext
        ctx.insert(CachedAnnouncement(id: 1, courseId: 1, title: "A", message: nil,
                                      postedAt: .now, authorName: "Prof"))
        try ctx.save()

        let first = Date(timeIntervalSince1970: 1_000_000)
        try repo.markAnnouncementRead(1, now: first)
        XCTAssertEqual(try repo.announcements(courseId: 1).first?.readAt, first)

        // A second call must not move the timestamp forward.
        try repo.markAnnouncementRead(1, now: first.addingTimeInterval(500))
        XCTAssertEqual(try repo.announcements(courseId: 1).first?.readAt, first)

        // Unknown id should not throw.
        XCTAssertNoThrow(try repo.markAnnouncementRead(999))
    }

    @MainActor
    func testAssignmentAndSubmissionSingleLookups() throws {
        let repo = CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))
        let ctx = repo.modelContainer.mainContext
        ctx.insert(CachedAssignment(id: 100, courseId: 1, groupId: 10, name: "Midterm",
                                    pointsPossible: 100, dueAt: .now, sortIndex: 0))
        ctx.insert(CachedSubmission(id: 1000, assignmentId: 100, courseId: 1, userId: 7,
                                    score: 92, workflowState: "graded", gradedAt: .now, submittedAt: nil))
        try ctx.save()

        XCTAssertEqual(try repo.assignment(id: 100)?.name, "Midterm")
        XCTAssertEqual(try repo.submission(assignmentId: 100)?.score, 92)
        XCTAssertNil(try repo.assignment(id: 999))
        XCTAssertNil(try repo.submission(assignmentId: 999))
    }

    @MainActor
    func testPurgeExpired() throws {
        let repo = CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))
        let ctx = repo.modelContainer.mainContext
        let now = Date()

        let oldRemovedCourse = CachedCourse(id: 1, name: "Old", courseCode: "OLD",
                                             applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 0,
                                             removedAt: now.addingTimeInterval(-91 * 86400))
        let recentRemovedCourse = CachedCourse(id: 2, name: "Recent", courseCode: "REC",
                                                applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 1,
                                                removedAt: now.addingTimeInterval(-5 * 86400))
        let oldChange = ChangeRecord(kind: .newGrade, courseId: 1, subjectId: nil,
                                      title: "Old change", detail: nil,
                                      occurredAt: now.addingTimeInterval(-31 * 86400))
        let recentChange = ChangeRecord(kind: .newGrade, courseId: 1, subjectId: nil,
                                         title: "Recent change", detail: nil,
                                         occurredAt: now.addingTimeInterval(-5 * 86400))
        let oldRemovedAssignment = CachedAssignment(id: 10, courseId: 1, groupId: 1, name: "OldAsg",
                                                     pointsPossible: 10, dueAt: nil, sortIndex: 0,
                                                     removedAt: now.addingTimeInterval(-91 * 86400))
        let recentRemovedAssignment = CachedAssignment(id: 11, courseId: 1, groupId: 1, name: "RecentAsg",
                                                        pointsPossible: 10, dueAt: nil, sortIndex: 1,
                                                        removedAt: now.addingTimeInterval(-5 * 86400))

        ctx.insert(oldRemovedCourse); ctx.insert(recentRemovedCourse)
        ctx.insert(oldChange); ctx.insert(recentChange)
        ctx.insert(oldRemovedAssignment); ctx.insert(recentRemovedAssignment)
        try ctx.save()

        try repo.purgeExpired(now: now)

        let remainingCourseIds = try ctx.fetch(FetchDescriptor<CachedCourse>()).map(\.id).sorted()
        XCTAssertEqual(remainingCourseIds, [2])

        let remainingChangeTitles = try ctx.fetch(FetchDescriptor<ChangeRecord>()).map(\.title)
        XCTAssertEqual(remainingChangeTitles, ["Recent change"])

        let remainingAssignmentIds = try ctx.fetch(FetchDescriptor<CachedAssignment>()).map(\.id).sorted()
        XCTAssertEqual(remainingAssignmentIds, [11])
    }

    @MainActor
    func testClearStoreEmptiesEveryModel() throws {
        let repo = CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))
        let ctx = repo.modelContainer.mainContext

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
        ctx.insert(CachedAnnouncement(id: 900, courseId: 1, title: "Welcome",
                                      message: "<p>Hi</p>", postedAt: .now, authorName: "Prof"))
        try ctx.save()

        try repo.clearStore()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedCourse>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedEnrollment>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedAssignmentGroup>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedAssignment>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedSubmission>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedComment>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<GradeSnapshot>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<ChangeRecord>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SyncMetadata>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedAnnouncement>()).count, 0)
    }
}
