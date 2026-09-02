import Foundation
import SwiftData
import CanvasCore

public enum SyncScope: Hashable, Sendable {
    case all
    case course(Int)
    case inbox
    case conversation(Int)
    case discussion(courseId: Int, topicId: Int)
    case planner(start: Date, end: Date)
    case modules(courseId: Int)
    case files(courseId: Int)
}
public enum SyncState: Equatable, Sendable { case idle; case syncing(SyncScope); case failed(String, Date) }
public enum SyncError: Error, CustomStringConvertible {
    case noClient
    // Surfaced to the user via `String(describing:)`, so it must not read as "noClient".
    public var description: String { "Not signed in to Canvas — add a token in Settings." }
}
public enum EntityKind: String, Sendable {
    case courses, enrollments, assignments, submissions, announcements
    case conversations, messages, discussionTopics, discussionEntries
    case plannerItems, calendarEvents
    case modules, moduleItems, folders, files
}

@ModelActor
public actor SyncEngine {
    private var client: APIClient?
    private var userDefaults: UserDefaults = .standard
    private var stateHandler: (@Sendable (SyncState) -> Void)?
    private var inFlight: [SyncScope: (force: Bool, task: Task<Void, any Error>)] = [:]
    public private(set) var state: SyncState = .idle

    public func configure(client: APIClient?) { self.client = client }
    public func setUserDefaults(_ ud: UserDefaults) { self.userDefaults = ud }
    public func setStateHandler(_ handler: @escaping @Sendable (SyncState) -> Void) {
        self.stateHandler = handler
    }

    private func setState(_ s: SyncState) {
        state = s
        stateHandler?(s)
    }

    /// Coalesces concurrent refreshes of the same scope. `refresh` suspends at every fetch,
    /// so without this two scenes navigating at once issue duplicate network work and the
    /// last one to finish overwrites `state` — misattributing one scope's failure to the other.
    /// A `force` request never joins a non-forced one in flight; it waits and then runs.
    public func refresh(_ scope: SyncScope, force: Bool = false) async throws {
        guard client != nil else { throw SyncError.noClient }
        while let existing = inFlight[scope] {
            if existing.force || !force { return try await existing.task.value }
            _ = try? await existing.task.value   // in-flight is weaker than ours: let it settle
            await Task.yield()                   // don't starve the owner's continuation
        }
        // The slot is cleared from *inside* the task, before its future is fulfilled, so a
        // waiter resuming ahead of the owner can never observe an already-completed entry
        // and re-await it without suspending — which would wedge this actor.
        let task = Task<Void, any Error> { [self] in
            defer { inFlight[scope] = nil }
            try await perform(scope, force: force)
        }
        // Safe to register after creating: the task body is actor-isolated and cannot start
        // until this call suspends at `task.value` below.
        inFlight[scope] = (force: force, task: task)
        try await task.value
    }

    private func perform(_ scope: SyncScope, force: Bool) async throws {
        guard let client else { throw SyncError.noClient }
        setState(.syncing(scope))
        do {
            switch scope {
            case .all:             try await syncAll(client: client, force: force)
            case .course(let id):  try await syncCourse(id, client: client, force: force)
            case .inbox:
                try await syncInbox(client: client, force: force)
            case .conversation(let id):
                try await syncConversation(id, client: client, force: force)
            case .discussion(let courseId, let topicId):
                try await syncDiscussionEntries(courseId: courseId, topicId: topicId, client: client, force: force)
            case .planner(let start, let end):
                try await syncPlanner(start: start, end: end, client: client, force: force)
            case .modules(let courseId):
                try await syncModules(courseId: courseId, client: client, force: force)
            case .files(let courseId):
                try await syncFiles(courseId: courseId, client: client, force: force)
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
        if force || !isFresh(.courses, scope: "all", now: now) {
            let fetched = try await fetchWithRetry { try await client.courses() }
            upsertCourses(fetched, now: now)
            touch(.courses, scope: "all", error: nil, at: now)
            try modelContext.save()
            LegacyHiddenCourses.clear(userDefaults: userDefaults)
        }

        let ids = activeCourseIds().filter { force || !isFresh(.enrollments, scope: "\($0)", now: now) }
        await withTaskGroup(of: (Int, Result<[Enrollment], any Error>).self) { group in
            var index = 0
            func addNext() {
                guard index < ids.count else { return }
                let id = ids[index]; index += 1
                group.addTask {
                    do {
                        let result = try await self.fetchWithRetry { try await client.enrollments(courseId: id) }
                        return (id, .success(result))
                    } catch { return (id, .failure(error)) }
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
        let legacy = LegacyHiddenCourses.ids(userDefaults: userDefaults)
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
                row.syllabusBody = c.syllabusBody
                row.sortIndex = i; row.removedAt = nil
            } else {
                modelContext.insert(CachedCourse(
                    id: c.id, name: c.name, courseCode: c.courseCode,
                    applyGroupWeights: c.applyAssignmentGroupWeights ?? false,
                    gradingSchemeJSON: schemeJSON,
                    hidden: legacy.contains(c.id), sortIndex: i,
                    syllabusBody: c.syllabusBody))
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

    // spec §2.5 TTL table (seconds)
    private static let ttl: [EntityKind: TimeInterval] = [
        .courses: 300, .enrollments: 300, .assignments: 900, .submissions: 300,
        .announcements: 1800,
        .conversations: 300, .messages: 300, .discussionTopics: 1800, .discussionEntries: 1800,
        .plannerItems: 900, .calendarEvents: 900,
        .modules: 21600, .moduleItems: 21600, .folders: 21600, .files: 21600,
    ]

    private func isFresh(_ kind: EntityKind, scope: String, now: Date) -> Bool {
        let key = "\(kind.rawValue):\(scope)"
        guard let last = fetchOne(FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.key == key }))?.lastSyncedAt else { return false }
        return now.timeIntervalSince(last) < (Self.ttl[kind] ?? 0)
    }

    // nonisolated: does not touch actor state, so fan-out tasks in syncAll aren't
    // serialized through the actor executor while retrying.
    private nonisolated func fetchWithRetry<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let APIError.rateLimited(retryAfter) {
            // `retryAfter` is server-controlled: clamp the low end too, since UInt64(negative) traps.
            let delay = max(0, min(retryAfter, 30))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await operation()
        }
    }

    // MARK: - .course

    private func syncCourse(_ courseId: Int, client: APIClient, force: Bool) async throws {
        let now = Date()

        // Real first-sync signal for dueSoon baseline suppression: was there ever a
        // successful submissions sync for this course before *this* run? (Not "are there
        // zero cached submissions right now" — a course can legitimately have none.)
        let submissionsMetaKey = "submissions:\(courseId)"
        let hadPriorSubmissionsSync = fetchOne(FetchDescriptor<SyncMetadata>(
            predicate: #Predicate<SyncMetadata> { $0.key == submissionsMetaKey }))?.lastSyncedAt != nil

        let needAssignments = force || !isFresh(.assignments, scope: "\(courseId)", now: now)
        let needSubmissions = force || !isFresh(.submissions, scope: "\(courseId)", now: now)
        let needAnnouncements = force || !isFresh(.announcements, scope: "\(courseId)", now: now)
        let needDiscussions = force || !isFresh(.discussionTopics, scope: "\(courseId)", now: now)
        guard needAssignments || needSubmissions || needAnnouncements || needDiscussions else { return }

        async let groupsFetch: [AssignmentGroup] = {
            guard needAssignments else { return [] }
            return try await fetchWithRetry { try await client.assignmentGroups(courseId: courseId) }
        }()
        async let subsFetch: [Submission] = {
            guard needSubmissions else { return [] }
            return try await fetchWithRetry { try await client.submissions(courseId: courseId) }
        }()
        async let announcementsFetch: [Announcement] = {
            guard needAnnouncements else { return [] }
            return try await fetchWithRetry { try await client.announcements(courseId: courseId) }
        }()
        async let discussionsFetch: [DiscussionTopic] = {
            guard needDiscussions else { return [] }
            return try await fetchWithRetry { try await client.discussionTopics(courseId: courseId) }
        }()

        var firstError: (any Error)?
        // A TTL-skipped fetch is not a failure — only fetches we actually attempted can fail.
        var groupsSucceeded = !needAssignments
        var submissionsSucceeded = !needSubmissions
        var announcementsSucceeded = !needAnnouncements
        var discussionsSucceeded = !needDiscussions

        if needAssignments {
            do {
                let groups = try await groupsFetch
                upsertGroups(groups, courseId: courseId, now: now)
                touch(.assignments, scope: "\(courseId)", error: nil, at: now)
                groupsSucceeded = true
            } catch {
                firstError = error
                touch(.assignments, scope: "\(courseId)", error: String(describing: error), at: now)
            }
        }

        if needSubmissions {
            do {
                let subs = try await subsFetch
                let old = submissionSnapshots(courseId: courseId)
                upsertSubmissions(subs, courseId: courseId)
                let names = assignmentNames(courseId: courseId)
                insert(ChangeDetector.submissionChanges(courseId: courseId, old: old,
                                                        new: subs, assignmentNames: names,
                                                        isBaseline: !hadPriorSubmissionsSync), now: now)
                if hadPriorSubmissionsSync {   // baseline suppression applies to dueSoon too
                    insert(dueSoonPending(courseId: courseId, subs: subs, now: now), now: now)
                }
                touch(.submissions, scope: "\(courseId)", error: nil, at: now)
                submissionsSucceeded = true
            } catch {
                if firstError == nil { firstError = error }
                touch(.submissions, scope: "\(courseId)", error: String(describing: error), at: now)
            }
        }

        if needAnnouncements {
            do {
                let items = try await announcementsFetch
                upsertAnnouncements(items, courseId: courseId, now: now)
                touch(.announcements, scope: "\(courseId)", error: nil, at: now)
                announcementsSucceeded = true
            } catch {
                if firstError == nil { firstError = error }
                touch(.announcements, scope: "\(courseId)", error: String(describing: error), at: now)
            }
        }

        if needDiscussions {
            do {
                let topics = try await discussionsFetch
                upsertDiscussionTopics(topics, courseId: courseId, now: now)
                touch(.discussionTopics, scope: "\(courseId)", error: nil, at: now)
                discussionsSucceeded = true
            } catch {
                if firstError == nil { firstError = error }
                touch(.discussionTopics, scope: "\(courseId)", error: String(describing: error), at: now)
            }
        }

        try modelContext.save()
        // Partial failure is normal (spec §2.5): throw only if *everything* attempted failed.
        if let firstError, !groupsSucceeded, !submissionsSucceeded, !announcementsSucceeded, !discussionsSucceeded {
            throw firstError
        }
    }

    private func upsertDiscussionTopics(_ items: [DiscussionTopic], courseId: Int, now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedDiscussionTopic>(
                predicate: #Predicate<CachedDiscussionTopic> { $0.courseId == courseId }))) ?? [])
                .map { ($0.id, $0) })
        let fetchedIds = Set(items.map(\.id))
        for t in items {
            let postedAt = CanvasDate.parse(t.postedAt)
            if let row = existing[t.id] {
                row.title = t.title; row.message = t.message; row.postedAt = postedAt
                row.replyCount = t.discussionSubentryCount ?? 0; row.htmlURL = t.htmlUrl; row.removedAt = nil
            } else {
                modelContext.insert(CachedDiscussionTopic(
                    id: t.id, courseId: courseId, title: t.title, message: t.message, postedAt: postedAt,
                    replyCount: t.discussionSubentryCount ?? 0, htmlURL: t.htmlUrl))
            }
        }
        for (id, row) in existing where !fetchedIds.contains(id) && row.removedAt == nil { row.removedAt = now }
    }

    private func upsertAnnouncements(_ items: [Announcement], courseId: Int, now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedAnnouncement>(
                predicate: #Predicate<CachedAnnouncement> { $0.courseId == courseId }))) ?? [])
                .map { ($0.id, $0) })
        let fetchedIds = Set(items.map(\.id))
        for a in items {
            let postedAt = CanvasDate.parse(a.postedAt)
            if let row = existing[a.id] {
                row.title = a.title; row.message = a.message; row.postedAt = postedAt
                row.authorName = a.author?.displayName; row.removedAt = nil
            } else {
                modelContext.insert(CachedAnnouncement(id: a.id, courseId: courseId, title: a.title,
                    message: a.message, postedAt: postedAt, authorName: a.author?.displayName))
            }
        }
        for (id, row) in existing where !fetchedIds.contains(id) && row.removedAt == nil { row.removedAt = now }
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
            let unlockAt = CanvasDate.parse(a.unlockAt)
            let lockAt = CanvasDate.parse(a.lockAt)
            let rubricJSON = a.rubric.flatMap { try? JSONEncoder().encode($0) }
            if let row = existingAssignments[a.id] {
                row.groupId = a.assignmentGroupId; row.name = a.name
                row.pointsPossible = a.pointsPossible; row.dueAt = dueAt
                row.sortIndex = i; row.removedAt = nil
                row.descriptionHTML = a.descriptionHTML
                row.submissionTypes = a.submissionTypes ?? []
                row.unlockAt = unlockAt; row.lockAt = lockAt
                row.htmlURL = a.htmlURL
                row.rubricJSON = rubricJSON
            } else {
                modelContext.insert(CachedAssignment(
                    id: a.id, courseId: courseId, groupId: a.assignmentGroupId, name: a.name,
                    pointsPossible: a.pointsPossible, dueAt: dueAt, sortIndex: i,
                    descriptionHTML: a.descriptionHTML, submissionTypes: a.submissionTypes ?? [],
                    unlockAt: unlockAt, lockAt: lockAt, htmlURL: a.htmlURL,
                    rubricJSON: rubricJSON))
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
            let rubricAssessmentJSON = sub.rubricAssessment.flatMap { try? JSONEncoder().encode($0) }
            if let row = existing[sub.id] {
                row.score = sub.score; row.workflowState = sub.workflowState
                row.gradedAt = gradedAt; row.submittedAt = submittedAt
                row.userId = sub.userId; row.assignmentId = sub.assignmentId
                row.late = sub.late ?? false; row.missing = sub.missing ?? false
                row.excused = sub.excused ?? false; row.attempt = sub.attempt
                row.rubricAssessmentJSON = rubricAssessmentJSON
            } else {
                modelContext.insert(CachedSubmission(
                    id: sub.id, assignmentId: sub.assignmentId, courseId: courseId,
                    userId: sub.userId, score: sub.score, workflowState: sub.workflowState,
                    gradedAt: gradedAt, submittedAt: submittedAt,
                    late: sub.late ?? false, missing: sub.missing ?? false,
                    excused: sub.excused ?? false, attempt: sub.attempt,
                    rubricAssessmentJSON: rubricAssessmentJSON))
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

    // MARK: - .discussion

    private func syncDiscussionEntries(courseId: Int, topicId: Int, client: APIClient, force: Bool) async throws {
        let now = Date()
        guard force || !isFresh(.discussionEntries, scope: "\(topicId)", now: now) else { return }
        let view = try await fetchWithRetry { try await client.discussionView(courseId: courseId, topicId: topicId) }
        let flat = flattenDiscussion(view)
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedDiscussionEntry>(
                predicate: #Predicate<CachedDiscussionEntry> { $0.topicId == topicId }))) ?? [])
                .map { ($0.id, $0) })
        let fetchedIds = Set(flat.map(\.id))
        for e in flat {
            let created = CanvasDate.parse(e.createdAt)
            if let row = existing[e.id] {
                row.parentId = e.parentId; row.depth = e.depth; row.sortIndex = e.sortIndex
                row.authorName = e.authorName; row.message = e.message; row.createdAt = created
            } else {
                modelContext.insert(CachedDiscussionEntry(
                    id: e.id, topicId: topicId, parentId: e.parentId, depth: e.depth, sortIndex: e.sortIndex,
                    authorName: e.authorName, message: e.message, createdAt: created))
            }
        }
        // Hard-delete entries removed upstream (a deleted reply should vanish; no history value here).
        for (id, row) in existing where !fetchedIds.contains(id) { modelContext.delete(row) }
        touch(.discussionEntries, scope: "\(topicId)", error: nil, at: now)
        try modelContext.save()
    }

    // MARK: - .inbox

    private func syncInbox(client: APIClient, force: Bool) async throws {
        let now = Date()
        guard force || !isFresh(.conversations, scope: "inbox", now: now) else { return }
        let inboxMetaKey = "conversations:inbox"
        let hadPrior = fetchOne(FetchDescriptor<SyncMetadata>(
            predicate: #Predicate<SyncMetadata> { $0.key == inboxMetaKey }))?.lastSyncedAt != nil

        let fetched = try await fetchWithRetry { try await client.conversations(scope: .inbox) }
        let old = conversationLastMessageDates()
        upsertConversations(fetched, now: now)
        insert(ChangeDetector.conversationChanges(old: old, new: fetched, isBaseline: !hadPrior), now: now)
        touch(.conversations, scope: "inbox", error: nil, at: now)
        try modelContext.save()
    }

    private func conversationLastMessageDates() -> [Int: Date?] {
        let rows = (try? modelContext.fetch(FetchDescriptor<CachedConversation>())) ?? []
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.lastMessageAt) })
    }

    private func upsertConversations(_ items: [Conversation], now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedConversation>())) ?? []).map { ($0.id, $0) })
        let fetchedIds = Set(items.map(\.id))
        for c in items {
            let participantsJSON = c.participants.flatMap { try? JSONEncoder().encode($0) }
            let lastAt = CanvasDate.parse(c.lastMessageAt)
            let state = c.workflowState ?? "read"
            if let row = existing[c.id] {
                row.subject = c.subject; row.lastMessageAt = lastAt
                row.lastMessageSnippet = c.lastMessage; row.workflowState = state
                row.contextName = c.contextName; row.messageCount = c.messageCount ?? row.messageCount
                if let participantsJSON { row.participantsJSON = participantsJSON }
                row.removedAt = nil
            } else {
                modelContext.insert(CachedConversation(
                    id: c.id, subject: c.subject, lastMessageAt: lastAt, lastMessageSnippet: c.lastMessage,
                    workflowState: state, participantsJSON: participantsJSON,
                    contextName: c.contextName, messageCount: c.messageCount ?? 0))
            }
        }
        // Soft-delete conversations that dropped out of the inbox scope (e.g. archived elsewhere).
        for (id, row) in existing where !fetchedIds.contains(id) && row.workflowState != "archived" && row.removedAt == nil {
            row.removedAt = now
        }
    }

    // MARK: - .conversation

    private func syncConversation(_ id: Int, client: APIClient, force: Bool) async throws {
        let now = Date()
        guard force || !isFresh(.messages, scope: "\(id)", now: now) else { return }
        let detail = try await fetchWithRetry { try await client.conversation(id: id) }
        // Reconcile parent row (adopt Canvas's authoritative workflow_state).
        upsertConversations([detail], now: now)
        upsertMessages(detail, now: now)
        touch(.messages, scope: "\(id)", error: nil, at: now)
        try modelContext.save()
    }

    private func upsertMessages(_ detail: Conversation, now: Date) {
        let names: [Int: String] = Dictionary(uniqueKeysWithValues: (detail.participants ?? []).compactMap { p in
            p.name.map { (p.id, $0) }
        })
        let convId = detail.id
        // Drop reconciled pending rows: real messages have arrived.
        let priorPending = (try? modelContext.fetch(FetchDescriptor<CachedMessage>(
            predicate: #Predicate<CachedMessage> { $0.conversationId == convId && $0.pending }))) ?? []
        for row in priorPending { modelContext.delete(row) }

        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedMessage>(
                predicate: #Predicate<CachedMessage> { $0.conversationId == convId }))) ?? [])
                .map { ($0.id, $0) })
        for m in detail.messages ?? [] {
            let created = CanvasDate.parse(m.createdAt)
            let authorId = m.authorId ?? 0
            let authorName = names[authorId]
            if let row = existing[m.id] {
                row.authorId = authorId; row.authorName = authorName
                row.body = m.body; row.createdAt = created; row.pending = false
            } else {
                modelContext.insert(CachedMessage(id: m.id, conversationId: convId, authorId: authorId,
                                                  authorName: authorName, body: m.body,
                                                  createdAt: created, pending: false))
            }
        }
    }

    // MARK: - .planner

    private func syncPlanner(start: Date, end: Date, client: APIClient, force: Bool) async throws {
        let now = Date()
        let scopeKey = "\(Int(start.timeIntervalSince1970))_\(Int(end.timeIntervalSince1970))"
        guard force || !isFresh(.plannerItems, scope: scopeKey, now: now) else { return }

        let items = try await fetchWithRetry { try await client.plannerItems(start: start, end: end) }
        let events = try await fetchWithRetry { try await client.calendarEvents(contextCodes: nil, start: start, end: end) }

        upsertPlannerItems(items, now: now)
        upsertCalendarEvents(events, now: now)

        touch(.plannerItems, scope: scopeKey, error: nil, at: now)
        touch(.calendarEvents, scope: scopeKey, error: nil, at: now)
        try modelContext.save()
    }

    private func upsertPlannerItems(_ items: [PlannerItem], now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedPlannerItem>())) ?? []).map { ($0.id, $0) })
        for item in items {
            let isSubmitted = item.submissions?.submitted ?? false
            let isMissing = item.submissions?.missing ?? false
            let isCompleted = item.plannerOverride?.markedComplete ?? false
            if let row = existing[item.id] {
                row.title = item.title
                row.courseId = item.courseId
                row.plannableId = item.plannableId
                row.plannableType = item.plannableType
                row.plannableDate = item.plannableDate
                row.htmlUrl = item.htmlUrl
                row.isSubmitted = isSubmitted
                row.isMissing = isMissing
                row.isCompleted = isCompleted
                row.updatedAt = now
            } else {
                modelContext.insert(CachedPlannerItem(
                    id: item.id,
                    title: item.title,
                    courseId: item.courseId,
                    plannableId: item.plannableId,
                    plannableType: item.plannableType,
                    plannableDate: item.plannableDate,
                    htmlUrl: item.htmlUrl,
                    isSubmitted: isSubmitted,
                    isMissing: isMissing,
                    isCompleted: isCompleted,
                    updatedAt: now
                ))
            }
        }
    }

    private func upsertCalendarEvents(_ events: [CalendarEvent], now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedCalendarEvent>())) ?? []).map { ($0.id, $0) })
        for event in events {
            if let row = existing[event.id] {
                row.title = event.title
                row.contextCode = event.contextCode
                row.courseId = event.courseId
                row.startAt = event.startAt
                row.endAt = event.endAt
                row.locationName = event.locationName
                row.eventDescription = event.description
                row.htmlUrl = event.htmlUrl
                row.updatedAt = now
            } else {
                modelContext.insert(CachedCalendarEvent(
                    id: event.id,
                    title: event.title,
                    contextCode: event.contextCode,
                    courseId: event.courseId,
                    startAt: event.startAt,
                    endAt: event.endAt,
                    locationName: event.locationName,
                    eventDescription: event.description,
                    htmlUrl: event.htmlUrl,
                    updatedAt: now
                ))
            }
        }
    }

    // MARK: - .modules

    private func syncModules(courseId: Int, client: APIClient, force: Bool) async throws {
        let now = Date()
        guard force || !isFresh(.modules, scope: "\(courseId)", now: now) else { return }
        let fetched = try await fetchWithRetry { try await client.modules(courseId: courseId) }
        upsertModules(fetched, courseId: courseId, now: now)
        touch(.modules, scope: "\(courseId)", error: nil, at: now)
        try modelContext.save()
    }

    private func upsertModules(_ fetched: [Module], courseId: Int, now: Date) {
        let existingModules = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedModule>(
                predicate: #Predicate<CachedModule> { $0.courseId == courseId }))) ?? []).map { ($0.id, $0) })
        let existingItems = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedModuleItem>(
                predicate: #Predicate<CachedModuleItem> { $0.courseId == courseId }))) ?? []).map { ($0.id, $0) })

        let fetchedModuleIds = Set(fetched.map(\.id))
        var fetchedItemIds: Set<Int> = []

        for (mIndex, m) in fetched.enumerated() {
            let mPos = m.position ?? (mIndex + 1)
            if let row = existingModules[m.id] {
                row.name = m.name
                row.position = mPos
                row.state = m.state
                row.unlockAt = m.unlockAt
                row.removedAt = nil
            } else {
                modelContext.insert(CachedModule(
                    id: m.id, courseId: courseId, name: m.name, position: mPos, state: m.state, unlockAt: m.unlockAt
                ))
            }

            if let items = m.items {
                for (iIndex, item) in items.enumerated() {
                    fetchedItemIds.insert(item.id)
                    let itemPos = item.position ?? (iIndex + 1)
                    if let row = existingItems[item.id] {
                        row.moduleId = m.id
                        row.title = item.title
                        row.position = itemPos
                        row.itemType = item.type
                        row.indent = item.indent ?? 0
                        row.contentId = item.contentId
                        row.htmlURL = item.htmlUrl
                        row.url = item.url
                        row.pageUrl = item.pageUrl
                        row.externalUrl = item.externalUrl
                        row.completionRequirementType = item.completionRequirement?.type
                        row.completionRequirementCompleted = item.completionRequirement?.completed
                        row.removedAt = nil
                    } else {
                        modelContext.insert(CachedModuleItem(
                            id: item.id,
                            moduleId: m.id,
                            courseId: courseId,
                            title: item.title,
                            position: itemPos,
                            itemType: item.type,
                            indent: item.indent ?? 0,
                            contentId: item.contentId,
                            htmlURL: item.htmlUrl,
                            url: item.url,
                            pageUrl: item.pageUrl,
                            externalUrl: item.externalUrl,
                            completionRequirementType: item.completionRequirement?.type,
                            completionRequirementCompleted: item.completionRequirement?.completed
                        ))
                    }
                }
            }
        }

        for (id, row) in existingModules where !fetchedModuleIds.contains(id) && row.removedAt == nil {
            row.removedAt = now
        }
        for (id, row) in existingItems where !fetchedItemIds.contains(id) && row.removedAt == nil {
            row.removedAt = now
        }
    }

    // MARK: - .files

    private func syncFiles(courseId: Int, client: APIClient, force: Bool) async throws {
        let now = Date()
        guard force || !isFresh(.files, scope: "\(courseId)", now: now) else { return }
        async let foldersFetch = fetchWithRetry { try await client.folders(courseId: courseId) }
        async let filesFetch = fetchWithRetry { try await client.files(courseId: courseId) }
        let (folders, files) = try await (foldersFetch, filesFetch)

        upsertFolders(folders, courseId: courseId, now: now)
        upsertFiles(files, courseId: courseId, now: now)

        touch(.folders, scope: "\(courseId)", error: nil, at: now)
        touch(.files, scope: "\(courseId)", error: nil, at: now)
        try modelContext.save()
    }

    private func upsertFolders(_ fetched: [CanvasFolder], courseId: Int, now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedFolder>(
                predicate: #Predicate<CachedFolder> { $0.courseId == courseId }))) ?? []).map { ($0.id, $0) })
        let fetchedIds = Set(fetched.map(\.id))

        for f in fetched {
            if let row = existing[f.id] {
                row.name = f.name
                row.parentFolderId = f.parentFolderId
                row.fullName = f.fullName
                row.removedAt = nil
            } else {
                modelContext.insert(CachedFolder(
                    id: f.id, courseId: courseId, parentFolderId: f.parentFolderId, name: f.name, fullName: f.fullName
                ))
            }
        }
        for (id, row) in existing where !fetchedIds.contains(id) && row.removedAt == nil {
            row.removedAt = now
        }
    }

    private func upsertFiles(_ fetched: [CanvasFile], courseId: Int, now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedFile>(
                predicate: #Predicate<CachedFile> { $0.courseId == courseId }))) ?? []).map { ($0.id, $0) })
        let fetchedIds = Set(fetched.map(\.id))

        for file in fetched {
            if let row = existing[file.id] {
                row.folderId = file.folderId
                row.displayName = file.displayName
                row.contentType = file.contentType
                row.size = file.size ?? 0
                row.url = file.url
                row.updatedAt = file.updatedAt
                row.removedAt = nil
                // localPath is preserved!
            } else {
                modelContext.insert(CachedFile(
                    id: file.id,
                    courseId: courseId,
                    folderId: file.folderId,
                    displayName: file.displayName,
                    contentType: file.contentType,
                    size: file.size ?? 0,
                    url: file.url,
                    updatedAt: file.updatedAt
                ))
            }
        }
        for (id, row) in existing where !fetchedIds.contains(id) && row.removedAt == nil {
            row.removedAt = now
        }
    }

    // MARK: - Writes

    public func markConversationRead(_ id: Int) async throws {
        guard let client else { throw SyncError.noClient }
        try await client.markConversationRead(id: id)
        if let row = fetchOne(FetchDescriptor<CachedConversation>(
            predicate: #Predicate<CachedConversation> { $0.id == id })) {
            row.workflowState = "read"
            try modelContext.save()
        }
    }

    /// The caller inserts the optimistic pending row (via the repository) before calling this;
    /// on success we re-fetch the thread, which deletes pending rows and installs the real ones.
    public func sendReply(conversationId: Int, body: String) async throws {
        guard let client else { throw SyncError.noClient }
        let detail = try await client.replyToConversation(id: conversationId, body: body)
        upsertConversations([detail], now: Date())
        upsertMessages(detail, now: Date())
        try modelContext.save()
    }

    public func compose(recipientIds: [Int], subject: String, body: String) async throws -> Int {
        guard let client else { throw SyncError.noClient }
        let created = try await client.createConversation(recipientIds: recipientIds, subject: subject, body: body)
        let now = Date()
        upsertConversations([created], now: now)
        upsertMessages(created, now: now)   // detail from compose may include the first message
        try modelContext.save()
        return created.id
    }
}
