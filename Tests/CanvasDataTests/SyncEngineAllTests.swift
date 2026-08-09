import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class SyncEngineAllTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "hiddenCourseIDs")
        super.tearDown()
    }

    func testRefreshAllPopulatesCoursesAndEnrollments() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        try await engine.refresh(.all)

        let repo = await CanvasRepository(modelContainer: container)
        let courses = try await repo.courses(includeHidden: true)
        XCTAssertEqual(courses.count, MockData.courses.count)

        let enrollment = try await repo.enrollment(courseId: MockData.csCourseId)
        XCTAssertEqual(enrollment?.currentScore, MockData.enrollments[MockData.csCourseId]?.grades?.currentScore)
    }

    func testRefreshAllIsIdempotent() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        try await engine.refresh(.all, force: true)
        try await engine.refresh(.all, force: true)

        let repo = await CanvasRepository(modelContainer: container)
        let courses = try await repo.courses(includeHidden: true)
        XCTAssertEqual(courses.count, MockData.courses.count)

        let changes = try await repo.changes(since: Date.distantPast)
        XCTAssertEqual(changes.count, 0)

        for course in MockData.courses {
            let snapshots = try await repo.gradeSnapshots(courseId: course.id)
            XCTAssertEqual(snapshots.count, 1, "expected exactly one snapshot for course \(course.id)")
        }
    }

    func testLegacyHiddenIdsMigrate() async throws {
        let suiteName = "testLegacyHiddenIdsMigrate_\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.set([MockData.mathCourseId], forKey: "hiddenCourseIDs")
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.setUserDefaults(userDefaults)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        try await engine.refresh(.all)

        let repo = await CanvasRepository(modelContainer: container)
        for course in MockData.courses {
            let cached = try await repo.course(id: course.id)
            let expectedHidden = course.id == MockData.mathCourseId
            XCTAssertEqual(cached?.hidden, expectedHidden, "course \(course.id) hidden mismatch")
        }

        XCTAssertNil(userDefaults.array(forKey: "hiddenCourseIDs"))
    }

    func testSnapshotAndGradeChangedOnScoreMove() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        try await engine.refresh(.all)

        let repo = await CanvasRepository(modelContainer: container)
        let csCourseId = MockData.csCourseId
        try await MainActor.run {
            let ctx = repo.modelContainer.mainContext
            let predicate = #Predicate<CachedEnrollment> { $0.courseId == csCourseId }
            let enrollment = try ctx.fetch(FetchDescriptor(predicate: predicate)).first
            enrollment?.currentScore = (enrollment?.currentScore ?? 0) - 2.0
            try ctx.save()
        }

        try await engine.refresh(.all, force: true)

        let snapshots = try await repo.gradeSnapshots(courseId: MockData.csCourseId)
        XCTAssertEqual(snapshots.count, 2)

        let changes = try await repo.changes(since: Date.distantPast)
        XCTAssertEqual(changes.filter { $0.changeKind == .gradeChanged }.count, 1)
    }

    func testCourseMissingFromFullFetchIsSoftDeleted() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        try await engine.refresh(.all)

        let repo = await CanvasRepository(modelContainer: container)
        try await MainActor.run {
            let ctx = repo.modelContainer.mainContext
            ctx.insert(CachedCourse(id: 424242, name: "Ghost Course", courseCode: "GHOST 000",
                                     applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 999))
            try ctx.save()
        }

        try await engine.refresh(.all, force: true)

        let ghost = try await repo.course(id: 424242)
        XCTAssertNotNil(ghost)
        XCTAssertNotNil(ghost?.removedAt)
    }
}
