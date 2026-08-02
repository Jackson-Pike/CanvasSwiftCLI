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

    // MARK: - .course

    private func syncCourse(_ courseId: Int, client: APIClient, force: Bool) async throws {
        let now = Date()
        async let groupsFetch = fetchWithRetry { try await client.assignmentGroups(courseId: courseId) }
        async let subsFetch = fetchWithRetry { try await client.submissions(courseId: courseId) }

        var firstError: (any Error)?

        do {
            let groups = try await groupsFetch
            upsertGroups(groups, courseId: courseId, now: now)
            touch(.assignments, scope: "\(courseId)", error: nil, at: now)
        } catch {
            firstError = error
            touch(.assignments, scope: "\(courseId)", error: String(describing: error), at: now)
        }

        do {
            let subs = try await subsFetch
            let old = submissionSnapshots(courseId: courseId)
            upsertSubmissions(subs, courseId: courseId)
            let names = assignmentNames(courseId: courseId)
            insert(ChangeDetector.submissionChanges(courseId: courseId, old: old,
                                                    new: subs, assignmentNames: names), now: now)
            if !old.isEmpty {   // baseline suppression applies to dueSoon too
                insert(dueSoonPending(courseId: courseId, subs: subs, now: now), now: now)
            }
            touch(.submissions, scope: "\(courseId)", error: nil, at: now)
        } catch {
            if firstError == nil { firstError = error }
            touch(.submissions, scope: "\(courseId)", error: String(describing: error), at: now)
        }

        try modelContext.save()
        // Partial failure is normal (spec §2.5): throw only if *everything* failed.
        if let firstError, fetchCount(FetchDescriptor<CachedAssignmentGroup>(
            predicate: #Predicate { $0.courseId == courseId })) == 0 {
            throw firstError
        }
    }

    private func upsertGroups(_ groups: [AssignmentGroup], courseId: Int, now: Date) {
        let existingGroups = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedAssignmentGroup>(
                predicate: #Predicate<CachedAssignmentGroup> { $0.courseId == courseId }))) ?? [])
                .map { ($0.id, $0) })
        let fetchedGroupIds = Set(groups.map(\.id))
        for g in groups {
            let dropLowest = g.rules?.dropLowest ?? 0
            let dropHighest = g.rules?.dropHighest ?? 0
            let neverDrop = g.rules?.neverDrop ?? []
            if let row = existingGroups[g.id] {
                row.name = g.name; row.groupWeight = g.groupWeight
                row.dropLowest = dropLowest; row.dropHighest = dropHighest
                row.neverDrop = neverDrop; row.removedAt = nil
            } else {
                modelContext.insert(CachedAssignmentGroup(
                    id: g.id, courseId: courseId, name: g.name, groupWeight: g.groupWeight,
                    dropLowest: dropLowest, dropHighest: dropHighest, neverDrop: neverDrop))
            }
        }
        for (id, row) in existingGroups where !fetchedGroupIds.contains(id) && row.removedAt == nil {
            row.removedAt = now
        }

        let existingAssignments = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedAssignment>(
                predicate: #Predicate<CachedAssignment> { $0.courseId == courseId }))) ?? [])
                .map { ($0.id, $0) })
        let flattened = groups.flatMap(\.assignments)
        let fetchedAssignmentIds = Set(flattened.map(\.id))
        for (i, a) in flattened.enumerated() {
            let dueAt = CanvasDate.parse(a.dueAt)
            if let row = existingAssignments[a.id] {
                row.groupId = a.assignmentGroupId; row.name = a.name
                row.pointsPossible = a.pointsPossible; row.dueAt = dueAt
                row.sortIndex = i; row.removedAt = nil
            } else {
                modelContext.insert(CachedAssignment(
                    id: a.id, courseId: courseId, groupId: a.assignmentGroupId, name: a.name,
                    pointsPossible: a.pointsPossible, dueAt: dueAt, sortIndex: i))
            }
        }
        for (id, row) in existingAssignments where !fetchedAssignmentIds.contains(id) && row.removedAt == nil {
            row.removedAt = now
        }
    }

    private func upsertSubmissions(_ subs: [Submission], courseId: Int) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedSubmission>(
                predicate: #Predicate<CachedSubmission> { $0.courseId == courseId }))) ?? [])
                .map { ($0.id, $0) })
        let existingComments = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedComment>())) ?? []).map { ($0.id, $0) })

        for sub in subs {
            let gradedAt = CanvasDate.parse(sub.gradedAt)
            let submittedAt = CanvasDate.parse(sub.submittedAt)
            if let row = existing[sub.id] {
                row.score = sub.score; row.workflowState = sub.workflowState
                row.gradedAt = gradedAt; row.submittedAt = submittedAt
                row.userId = sub.userId; row.assignmentId = sub.assignmentId
            } else {
                modelContext.insert(CachedSubmission(
                    id: sub.id, assignmentId: sub.assignmentId, courseId: courseId,
                    userId: sub.userId, score: sub.score, workflowState: sub.workflowState,
                    gradedAt: gradedAt, submittedAt: submittedAt))
            }

            for comment in sub.submissionComments ?? [] {
                guard let cid = comment.id else { continue }
                let createdAt = CanvasDate.parse(comment.createdAt)
                if let row = existingComments[cid] {
                    row.submissionId = sub.id; row.assignmentId = sub.assignmentId
                    row.authorId = comment.authorId; row.authorName = comment.authorName
                    row.body = comment.comment; row.createdAt = createdAt
                } else {
                    modelContext.insert(CachedComment(
                        id: cid, submissionId: sub.id, assignmentId: sub.assignmentId,
                        authorId: comment.authorId, authorName: comment.authorName,
                        body: comment.comment, createdAt: createdAt))
                }
            }
        }
    }

    private func submissionSnapshots(courseId: Int) -> [Int: SubmissionSnapshot] {
        let subs = (try? modelContext.fetch(FetchDescriptor<CachedSubmission>(
            predicate: #Predicate<CachedSubmission> { $0.courseId == courseId }))) ?? []
        var result: [Int: SubmissionSnapshot] = [:]
        for sub in subs {
            let subId = sub.id
            let comments = (try? modelContext.fetch(FetchDescriptor<CachedComment>(
                predicate: #Predicate<CachedComment> { $0.submissionId == subId }))) ?? []
            let commentIds = Set(comments.map(\.id))
            result[sub.assignmentId] = SubmissionSnapshot(
                score: sub.score, workflowState: sub.workflowState, commentIds: commentIds)
        }
        return result
    }

    private func assignmentNames(courseId: Int) -> [Int: String] {
        let assignments = (try? modelContext.fetch(FetchDescriptor<CachedAssignment>(
            predicate: #Predicate<CachedAssignment> { $0.courseId == courseId }))) ?? []
        return Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0.name) })
    }

    private func dueSoonPending(courseId: Int, subs: [Submission], now: Date) -> [PendingChange] {
        let assignments = ((try? modelContext.fetch(FetchDescriptor<CachedAssignment>(
            predicate: #Predicate<CachedAssignment> { $0.courseId == courseId }))) ?? [])
            .filter { $0.removedAt == nil }
            .map { (id: $0.id, name: $0.name, dueAt: $0.dueAt) }
        // BYUH never returns workflow_state "submitted" (spec §3.1); treat graded as submitted too.
        let submitted = Set(subs.filter { $0.submittedAt != nil || $0.workflowState == "graded" }
            .map(\.assignmentId))
        let notified = Set((try? modelContext.fetch(FetchDescriptor<ChangeRecord>(
            predicate: #Predicate<ChangeRecord> { $0.courseId == courseId && $0.kind == "dueSoon" })))
            ?? []).compactMap(\.subjectId)
        return ChangeDetector.dueSoonChanges(courseId: courseId, assignments: assignments,
                                             submittedAssignmentIds: submitted,
                                             alreadyNotified: Set(notified), now: now)
    }

    private func fetchCount<T: PersistentModel>(_ d: FetchDescriptor<T>) -> Int {
        (try? modelContext.fetchCount(d)) ?? 0
    }
}
