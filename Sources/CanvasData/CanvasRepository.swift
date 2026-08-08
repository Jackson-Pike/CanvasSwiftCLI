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
        try context.delete(model: GradeSnapshot.self)
        try context.delete(model: ChangeRecord.self)
        try context.delete(model: SyncMetadata.self)
        try context.save()
    }
}
