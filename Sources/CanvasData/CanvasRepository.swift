import Foundation
import SwiftData
import CanvasCore

/// Main-actor read/flag/purge layer over the SwiftData store. Views never call
/// APIClient directly; all reads route through this repository.
@MainActor
public final class CanvasRepository {
    public let modelContainer: ModelContainer

    private var context: ModelContext { modelContainer.mainContext }

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Reads

    public func courses(includeHidden: Bool = false) throws -> [CachedCourse] {
        let all = try context.fetch(FetchDescriptor<CachedCourse>())
        return all
            .filter { $0.removedAt == nil && (includeHidden || !$0.hidden) }
            .sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.name < rhs.name
            }
    }

    public func course(id: Int) throws -> CachedCourse? {
        let predicate = #Predicate<CachedCourse> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    public func enrollment(courseId: Int) throws -> CachedEnrollment? {
        let predicate = #Predicate<CachedEnrollment> { $0.courseId == courseId }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    public func assignmentGroups(courseId: Int) throws -> [CachedAssignmentGroup] {
        let predicate = #Predicate<CachedAssignmentGroup> { $0.courseId == courseId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all.filter { $0.removedAt == nil }
    }

    public func assignments(courseId: Int) throws -> [CachedAssignment] {
        let predicate = #Predicate<CachedAssignment> { $0.courseId == courseId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all
            .filter { $0.removedAt == nil }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    public func submissions(courseId: Int) throws -> [CachedSubmission] {
        let predicate = #Predicate<CachedSubmission> { $0.courseId == courseId }
        return try context.fetch(FetchDescriptor(predicate: predicate))
    }

    public func assignment(id: Int) throws -> CachedAssignment? {
        let predicate = #Predicate<CachedAssignment> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    public func submission(assignmentId: Int) throws -> CachedSubmission? {
        let predicate = #Predicate<CachedSubmission> { $0.assignmentId == assignmentId }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    public func announcements(courseId: Int) throws -> [CachedAnnouncement] {
        let predicate = #Predicate<CachedAnnouncement> { $0.courseId == courseId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all
            .filter { $0.removedAt == nil }
            .sorted { ($0.postedAt ?? .distantPast) > ($1.postedAt ?? .distantPast) }
    }

    public func conversations(scope: ConversationScope) throws -> [CachedConversation] {
        let all = try context.fetch(FetchDescriptor<CachedConversation>())
            .filter { $0.removedAt == nil }
        let scoped: [CachedConversation]
        switch scope {
        case .inbox:    scoped = all.filter { $0.workflowState != "archived" }
        case .unread:   scoped = all.filter { $0.workflowState == "unread" }
        case .archived: scoped = all.filter { $0.workflowState == "archived" }
        }
        return scoped.sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
    }

    public func conversation(id: Int) throws -> CachedConversation? {
        let predicate = #Predicate<CachedConversation> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    public func messages(conversationId: Int) throws -> [CachedMessage] {
        let predicate = #Predicate<CachedMessage> { $0.conversationId == conversationId }
        return try context.fetch(FetchDescriptor(predicate: predicate))
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    public func unseenConversationCount() throws -> Int {
        try context.fetch(FetchDescriptor<CachedConversation>())
            .filter { $0.removedAt == nil && $0.workflowState == "unread" }.count
    }

    public func discussionTopics(courseId: Int) throws -> [CachedDiscussionTopic] {
        let predicate = #Predicate<CachedDiscussionTopic> { $0.courseId == courseId }
        return try context.fetch(FetchDescriptor(predicate: predicate))
            .filter { $0.removedAt == nil }
            .sorted { ($0.postedAt ?? .distantPast) > ($1.postedAt ?? .distantPast) }
    }

    public func discussionEntries(topicId: Int) throws -> [CachedDiscussionEntry] {
        let predicate = #Predicate<CachedDiscussionEntry> { $0.topicId == topicId }
        return try context.fetch(FetchDescriptor(predicate: predicate)).sorted { $0.sortIndex < $1.sortIndex }
    }

    // MARK: - Conversation writes (optimistic-local)

    /// Inserts an optimistic outgoing message and returns its temporary negative id
    /// (negative so it never collides with a real Canvas id). Reconciled away on next detail sync.
    @discardableResult
    public func insertPendingMessage(conversationId: Int, body: String, authorId: Int,
                                     authorName: String?, now: Date = .init()) throws -> Int {
        let tempId = -Int(Date().timeIntervalSince1970 * 1000)
        context.insert(CachedMessage(id: tempId, conversationId: conversationId, authorId: authorId,
                                     authorName: authorName, body: body, createdAt: now, pending: true))
        try context.save()
        return tempId
    }

    public func removePendingMessages(conversationId: Int) throws {
        let predicate = #Predicate<CachedMessage> { $0.conversationId == conversationId && $0.pending }
        for row in try context.fetch(FetchDescriptor(predicate: predicate)) { context.delete(row) }
        try context.save()
    }

    public func markConversationReadLocal(id: Int) throws {
        guard let row = try conversation(id: id) else { return }
        row.workflowState = "read"
        try context.save()
    }

    public func comments(assignmentId: Int) throws -> [CachedComment] {
        let predicate = #Predicate<CachedComment> { $0.assignmentId == assignmentId }
        return try context.fetch(FetchDescriptor(predicate: predicate))
    }

    public func changes(since: Date) throws -> [ChangeRecord] {
        let all = try context.fetch(FetchDescriptor<ChangeRecord>())
        return all
            .filter { $0.occurredAt >= since }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    public func unseenChanges() throws -> [ChangeRecord] {
        let predicate = #Predicate<ChangeRecord> { $0.seenAt == nil }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all.sorted { $0.occurredAt > $1.occurredAt }
    }

    public func markChangesSeen(now: Date = .init()) throws {
        let predicate = #Predicate<ChangeRecord> { $0.seenAt == nil }
        let unseen = try context.fetch(FetchDescriptor(predicate: predicate))
        for record in unseen {
            record.seenAt = now
        }
        try context.save()
    }

    public func gradeSnapshots(courseId: Int) throws -> [GradeSnapshot] {
        let predicate = #Predicate<GradeSnapshot> { $0.courseId == courseId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all.sorted { $0.capturedAt < $1.capturedAt }
    }

    public func lastSyncedAt(entityKind: String, scopeId: String) throws -> Date? {
        let key = "\(entityKind):\(scopeId)"
        let predicate = #Predicate<SyncMetadata> { $0.key == key }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first?.lastSyncedAt
    }

    // MARK: - Time & To-Do Queries

    public func plannerItems(start: Date? = nil, end: Date? = nil) throws -> [CachedPlannerItem] {
        let all = try context.fetch(FetchDescriptor<CachedPlannerItem>())
        return all.filter { item in
            guard let date = item.plannableDate else { return true }
            if let start = start, date < start { return false }
            if let end = end, date > end { return false }
            return true
        }.sorted { ($0.plannableDate ?? .distantFuture) < ($1.plannableDate ?? .distantFuture) }
    }

    public func calendarEvents(start: Date? = nil, end: Date? = nil) throws -> [CachedCalendarEvent] {
        let all = try context.fetch(FetchDescriptor<CachedCalendarEvent>())
        return all.filter { event in
            guard let date = event.startAt else { return true }
            if let start = start, date < start { return false }
            if let end = end, date > end { return false }
            return true
        }.sorted { ($0.startAt ?? .distantFuture) < ($1.startAt ?? .distantFuture) }
    }

    public func toDoMissing(now: Date = Date()) throws -> [CachedPlannerItem] {
        let all = try context.fetch(FetchDescriptor<CachedPlannerItem>())
        return all.filter { item in
            if item.isCompleted { return false }
            if item.isMissing { return true }
            if let date = item.plannableDate, date < now, !item.isSubmitted { return true }
            return false
        }.sorted { ($0.plannableDate ?? .distantPast) > ($1.plannableDate ?? .distantPast) }
    }

    public func toDoDueThisWeek(now: Date = Date()) throws -> [CachedPlannerItem] {
        let weekEnd = now.addingTimeInterval(7 * 86400)
        let all = try context.fetch(FetchDescriptor<CachedPlannerItem>())
        return all.filter { item in
            guard let date = item.plannableDate else { return false }
            if item.isCompleted || item.isSubmitted { return false }
            return date >= now && date <= weekEnd
        }.sorted { ($0.plannableDate ?? .distantFuture) < ($1.plannableDate ?? .distantFuture) }
    }

    public func toDoAwaitingGrade() throws -> [CachedSubmission] {
        let all = try context.fetch(FetchDescriptor<CachedSubmission>())
        return all.filter { sub in
            if sub.score != nil { return false }
            if sub.workflowState == "graded" && sub.score == nil { return true }
            if sub.submittedAt != nil || sub.workflowState == "submitted" || sub.workflowState == "pending_review" { return true }
            return false
        }.sorted { ($0.submittedAt ?? .distantPast) > ($1.submittedAt ?? .distantPast) }
    }

    // MARK: - Flags

    public func setHidden(_ hidden: Bool, courseId: Int) throws {
        guard let course = try course(id: courseId) else { return }
        course.hidden = hidden
        try context.save()
    }

    /// Device-local read tracking — never round-tripped to Canvas, and never
    /// overwritten once set, so a re-sync can't resurrect an unread dot.
    public func markAnnouncementRead(_ id: Int, now: Date = .init()) throws {
        let predicate = #Predicate<CachedAnnouncement> { $0.id == id }
        guard let row = try context.fetch(FetchDescriptor(predicate: predicate)).first else { return }
        if row.readAt == nil {
            row.readAt = now
            try context.save()
        }
    }

    public func setPinned(_ pinned: Bool, courseId: Int) throws {
        guard let course = try course(id: courseId) else { return }
        course.pinned = pinned
        try context.save()
    }

    // MARK: - Purge / clear

    public func purgeExpired(now: Date = .init()) throws {
        let courseThreshold = now.addingTimeInterval(-90 * 86400)
        let changeThreshold = now.addingTimeInterval(-30 * 86400)

        for course in try context.fetch(FetchDescriptor<CachedCourse>())
        where course.removedAt.map({ $0 < courseThreshold }) ?? false {
            context.delete(course)
        }
        for group in try context.fetch(FetchDescriptor<CachedAssignmentGroup>())
        where group.removedAt.map({ $0 < courseThreshold }) ?? false {
            context.delete(group)
        }
        for assignment in try context.fetch(FetchDescriptor<CachedAssignment>())
        where assignment.removedAt.map({ $0 < courseThreshold }) ?? false {
            context.delete(assignment)
        }
        for change in try context.fetch(FetchDescriptor<ChangeRecord>())
        where change.occurredAt < changeThreshold {
            context.delete(change)
        }
        for convo in try context.fetch(FetchDescriptor<CachedConversation>())
        where convo.removedAt.map({ $0 < courseThreshold }) ?? false {
            context.delete(convo)
        }
        for topic in try context.fetch(FetchDescriptor<CachedDiscussionTopic>())
        where topic.removedAt.map({ $0 < courseThreshold }) ?? false {
            context.delete(topic)
        }

        try context.save()
    }

    public func clearStore() throws {
        try context.delete(model: CachedCourse.self)
        try context.delete(model: CachedEnrollment.self)
        try context.delete(model: CachedAssignmentGroup.self)
        try context.delete(model: CachedAssignment.self)
        try context.delete(model: CachedSubmission.self)
        try context.delete(model: CachedComment.self)
        try context.delete(model: CachedAnnouncement.self)
        try context.delete(model: CachedConversation.self)
        try context.delete(model: CachedMessage.self)
        try context.delete(model: CachedDiscussionTopic.self)
        try context.delete(model: CachedDiscussionEntry.self)
        try context.delete(model: CachedPlannerItem.self)
        try context.delete(model: CachedCalendarEvent.self)
        try context.delete(model: CachedModule.self)
        try context.delete(model: CachedModuleItem.self)
        try context.delete(model: CachedFolder.self)
        try context.delete(model: CachedFile.self)
        try context.delete(model: GradeSnapshot.self)
        try context.delete(model: ChangeRecord.self)
        try context.delete(model: SyncMetadata.self)
        try context.save()
    }

    // MARK: - Modules & Files Queries

    public func modules(courseId: Int) throws -> [CachedModule] {
        let predicate = #Predicate<CachedModule> { $0.courseId == courseId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all
            .filter { $0.removedAt == nil }
            .sorted { $0.position < $1.position }
    }

    public func moduleItems(moduleId: Int) throws -> [CachedModuleItem] {
        let predicate = #Predicate<CachedModuleItem> { $0.moduleId == moduleId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all
            .filter { $0.removedAt == nil }
            .sorted { $0.position < $1.position }
    }

    public func folders(courseId: Int) throws -> [CachedFolder] {
        let predicate = #Predicate<CachedFolder> { $0.courseId == courseId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all
            .filter { $0.removedAt == nil }
            .sorted { $0.name < $1.name }
    }

    public func files(courseId: Int) throws -> [CachedFile] {
        let predicate = #Predicate<CachedFile> { $0.courseId == courseId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all
            .filter { $0.removedAt == nil }
            .sorted { $0.displayName < $1.displayName }
    }

    public func filesInFolder(folderId: Int) throws -> [CachedFile] {
        let predicate = #Predicate<CachedFile> { $0.folderId == folderId }
        let all = try context.fetch(FetchDescriptor(predicate: predicate))
        return all
            .filter { $0.removedAt == nil }
            .sorted { $0.displayName < $1.displayName }
    }

    public func updateLocalPath(fileId: Int, localPath: String?) throws {
        let predicate = #Predicate<CachedFile> { $0.id == fileId }
        if let file = try context.fetch(FetchDescriptor(predicate: predicate)).first {
            file.localPath = localPath
            try context.save()
        }
    }

    // MARK: - Global Search (⌘K)

    public func search(query: String) throws -> [SearchResultItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var results: [SearchResultItem] = []

        // Courses
        let courses = try context.fetch(FetchDescriptor<CachedCourse>())
        for c in courses where c.removedAt == nil {
            if c.name.lowercased().contains(q) || c.courseCode.lowercased().contains(q) {
                results.append(SearchResultItem(
                    id: "course_\(c.id)",
                    title: c.name,
                    subtitle: c.courseCode,
                    category: .course,
                    target: .course(id: c.id, tab: "grades")
                ))
            }
        }

        // Assignments
        let assignments = try context.fetch(FetchDescriptor<CachedAssignment>())
        for a in assignments where a.removedAt == nil {
            if a.name.lowercased().contains(q) || (a.descriptionHTML?.lowercased().contains(q) == true) {
                let courseName = (try? course(id: a.courseId))?.courseCode ?? "Course"
                results.append(SearchResultItem(
                    id: "assignment_\(a.id)",
                    title: a.name,
                    subtitle: "\(courseName) Assignment",
                    category: .assignment,
                    target: .assignment(courseId: a.courseId, assignmentId: a.id)
                ))
            }
        }

        // Announcements
        let announcements = try context.fetch(FetchDescriptor<CachedAnnouncement>())
        for ann in announcements where ann.removedAt == nil {
            if ann.title.lowercased().contains(q) || (ann.message?.lowercased().contains(q) == true) {
                let courseName = (try? course(id: ann.courseId))?.courseCode ?? "Course"
                results.append(SearchResultItem(
                    id: "announcement_\(ann.id)",
                    title: ann.title,
                    subtitle: "\(courseName) Announcement",
                    category: .announcement,
                    target: .course(id: ann.courseId, tab: "announcements")
                ))
            }
        }

        // Discussions
        let topics = try context.fetch(FetchDescriptor<CachedDiscussionTopic>())
        for t in topics where t.removedAt == nil {
            if t.title.lowercased().contains(q) || (t.message?.lowercased().contains(q) == true) {
                let courseName = (try? course(id: t.courseId))?.courseCode ?? "Course"
                results.append(SearchResultItem(
                    id: "discussion_\(t.id)",
                    title: t.title,
                    subtitle: "\(courseName) Discussion",
                    category: .discussion,
                    target: .course(id: t.courseId, tab: "discussions")
                ))
            }
        }

        // Files
        let files = try context.fetch(FetchDescriptor<CachedFile>())
        for f in files where f.removedAt == nil {
            if f.displayName.lowercased().contains(q) {
                let courseName = (try? course(id: f.courseId))?.courseCode ?? "Course"
                results.append(SearchResultItem(
                    id: "file_\(f.id)",
                    title: f.displayName,
                    subtitle: "\(courseName) File",
                    category: .file,
                    target: .course(id: f.courseId, tab: "files")
                ))
            }
        }

        // Module Items
        let items = try context.fetch(FetchDescriptor<CachedModuleItem>())
        for item in items where item.removedAt == nil {
            if item.title.lowercased().contains(q) {
                let courseName = (try? course(id: item.courseId))?.courseCode ?? "Course"
                let target: SearchResultTarget?
                if item.itemType == "Assignment", let contentId = item.contentId {
                    target = .assignment(courseId: item.courseId, assignmentId: contentId)
                } else if let extUrl = item.externalUrl {
                    target = .external(url: extUrl)
                } else {
                    target = .course(id: item.courseId, tab: "modules")
                }
                results.append(SearchResultItem(
                    id: "module_item_\(item.id)",
                    title: item.title,
                    subtitle: "\(courseName) Module Item (\(item.itemType))",
                    category: .moduleItem,
                    target: target
                ))
            }
        }

        return results
    }
}

