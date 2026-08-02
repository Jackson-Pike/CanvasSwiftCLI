import Foundation
import SwiftData
import CanvasCore

public enum SyncScope: Equatable, Sendable { case all; case course(Int) }
public enum SyncState: Equatable, Sendable { case idle; case syncing(SyncScope); case failed(String, Date) }
public enum SyncError: Error { case noClient }
public enum EntityKind: String, Sendable { case courses, enrollments, assignments, submissions }

@ModelActor
public actor SyncEngine {
    private var client: APIClient?
    private var stateHandler: (@Sendable (SyncState) -> Void)?
    public private(set) var state: SyncState = .idle

    public func configure(client: APIClient?) { self.client = client }
    public func setStateHandler(_ handler: @escaping @Sendable (SyncState) -> Void) {
        self.stateHandler = handler
    }

    private func setState(_ s: SyncState) {
        state = s
        stateHandler?(s)
    }

    public func refresh(_ scope: SyncScope, force: Bool = false) async throws {
        guard let client else { throw SyncError.noClient }
        setState(.syncing(scope))
        do {
            switch scope {
            case .all:             try await syncAll(client: client, force: force)
            case .course(let id):  try await syncCourse(id, client: client, force: force)
            }
            setState(.idle)
        } catch {
            setState(.failed(String(describing: error), Date()))
            throw error
        }
    }

    // MARK: - .all

    private func syncAll(client: APIClient, force: Bool) async throws {
        let now = Date()
        let fetched = try await fetchWithRetry { try await client.courses() }
        upsertCourses(fetched, now: now)
        touch(.courses, scope: "all", error: nil, at: now)
        try modelContext.save()
        LegacyHiddenCourses.clear()

        let ids = activeCourseIds()
        await withTaskGroup(of: (Int, Result<[Enrollment], any Error>).self) { group in
            var index = 0
            func addNext() {
                guard index < ids.count else { return }
                let id = ids[index]; index += 1
                group.addTask {
                    do { return (id, .success(try await client.enrollments(courseId: id))) }
                    catch { return (id, .failure(error)) }
                }
            }
            for _ in 0..<min(4, ids.count) { addNext() }   // spec §2.5: fan-out cap 4
            for await (id, result) in group {
                applyEnrollment(result, courseId: id, now: Date())
                addNext()
            }
        }
        try modelContext.save()
    }

    private func upsertCourses(_ fetched: [Course], now: Date) {
        let legacy = LegacyHiddenCourses.ids()
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedCourse>())) ?? []).map { ($0.id, $0) })
        let fetchedIds = Set(fetched.map(\.id))
        for (i, c) in fetched.enumerated() {
            let schemeJSON = c.gradingScheme.flatMap {
                try? JSONEncoder().encode($0.map { SchemePair(name: $0.name, value: $0.value) })
            }
            if let row = existing[c.id] {
                row.name = c.name; row.courseCode = c.courseCode
                row.applyGroupWeights = c.applyAssignmentGroupWeights ?? false
                row.gradingSchemeJSON = schemeJSON
                row.sortIndex = i; row.removedAt = nil
            } else {
                modelContext.insert(CachedCourse(
                    id: c.id, name: c.name, courseCode: c.courseCode,
                    applyGroupWeights: c.applyAssignmentGroupWeights ?? false,
                    gradingSchemeJSON: schemeJSON,
                    hidden: legacy.contains(c.id), sortIndex: i))
            }
        }
        for (id, row) in existing where !fetchedIds.contains(id) && row.removedAt == nil {
            row.removedAt = now   // soft delete (spec §2.5)
        }
    }

    private func applyEnrollment(_ result: Result<[Enrollment], any Error>, courseId: Int, now: Date) {
        switch result {
        case .failure(let error):
            touch(.enrollments, scope: "\(courseId)", error: String(describing: error), at: now)
        case .success(let enrollments):
            let newScore = enrollments.first?.grades?.currentScore
            let newGradeLetter = enrollments.first?.grades?.currentGrade
            let existing = fetchOne(FetchDescriptor<CachedEnrollment>(
                predicate: #Predicate { $0.courseId == courseId }))
            let oldScore = existing?.currentScore
            let hadPrior = existing != nil
            if let row = existing {
                row.currentScore = newScore; row.currentGrade = newGradeLetter
            } else {
                modelContext.insert(CachedEnrollment(courseId: courseId,
                                                     currentScore: newScore, currentGrade: newGradeLetter))
            }
            if let score = newScore, oldScore != score {
                let scale = fetchOne(FetchDescriptor<CachedCourse>(
                    predicate: #Predicate { $0.id == courseId }))?.gradingScale ?? byuhDefaultScale
                modelContext.insert(GradeSnapshot(courseId: courseId, capturedAt: now,
                                                  percent: score,
                                                  letter: letterGrade(for: score, scale: scale)))
            }
            if hadPrior {
                let courseName = fetchOne(FetchDescriptor<CachedCourse>(
                    predicate: #Predicate { $0.id == courseId }))?.name ?? "Course"
                if let change = ChangeDetector.gradeChange(courseId: courseId, courseName: courseName,
                                                           oldPercent: oldScore, newPercent: newScore) {
                    insert([change], now: now)
                }
            }
            touch(.enrollments, scope: "\(courseId)", error: nil, at: now)
        }
    }

    // MARK: - shared helpers

    private func activeCourseIds() -> [Int] {
        ((try? modelContext.fetch(FetchDescriptor<CachedCourse>())) ?? [])
            .filter { $0.removedAt == nil }
            .map(\.id)
    }

    private func fetchOne<T: PersistentModel>(_ d: FetchDescriptor<T>) -> T? {
        var d = d; d.fetchLimit = 1
        return (try? modelContext.fetch(d))?.first
    }

    private func insert(_ changes: [PendingChange], now: Date) {
        for c in changes {
            modelContext.insert(ChangeRecord(kind: c.kind, courseId: c.courseId,
                                             subjectId: c.subjectId, title: c.title,
                                             detail: c.detail, occurredAt: now))
        }
    }

    private func touch(_ kind: EntityKind, scope: String, error: String?, at date: Date) {
        let key = "\(kind.rawValue):\(scope)"
        let row = fetchOne(FetchDescriptor<SyncMetadata>(predicate: #Predicate { $0.key == key }))
            ?? { let m = SyncMetadata(entityKind: kind.rawValue, scopeId: scope)
                 modelContext.insert(m); return m }()
        if error == nil { row.lastSyncedAt = date }
        row.lastErrorDescription = error
    }

    // Task 9 replaces this passthrough with rate-limit backoff.
    private func fetchWithRetry<T>(_ operation: () async throws -> T) async throws -> T {
        try await operation()
    }

    // Task 8 fills this in.
    private func syncCourse(_ courseId: Int, client: APIClient, force: Bool) async throws {}
}
