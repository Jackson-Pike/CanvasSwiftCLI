import Foundation
import SwiftData

@Model
public final class GradeSnapshot {
    public var courseId: Int
    public var capturedAt: Date
    public var percent: Double
    public var letter: String

    public init(courseId: Int, capturedAt: Date, percent: Double, letter: String) {
        self.courseId = courseId; self.capturedAt = capturedAt
        self.percent = percent; self.letter = letter
    }
}

@Model
public final class ChangeRecord {
    @Attribute(.unique) public var id: UUID
    public var kind: String            // ChangeKind.rawValue (SwiftData predicates want plain types)
    public var courseId: Int
    public var subjectId: Int?
    public var title: String
    public var detail: String?
    public var occurredAt: Date
    public var seenAt: Date?

    public var changeKind: ChangeKind? { ChangeKind(rawValue: kind) }

    public init(kind: ChangeKind, courseId: Int, subjectId: Int?, title: String,
                detail: String?, occurredAt: Date, seenAt: Date? = nil) {
        self.id = UUID(); self.kind = kind.rawValue; self.courseId = courseId
        self.subjectId = subjectId; self.title = title; self.detail = detail
        self.occurredAt = occurredAt; self.seenAt = seenAt
    }
}

@Model
public final class SyncMetadata {
    @Attribute(.unique) public var key: String     // "\(entityKind):\(scopeId)"
    public var entityKind: String
    public var scopeId: String
    public var lastSyncedAt: Date?
    public var lastErrorDescription: String?

    public init(entityKind: String, scopeId: String) {
        self.key = "\(entityKind):\(scopeId)"
        self.entityKind = entityKind; self.scopeId = scopeId
    }
}
