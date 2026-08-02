import Foundation
import SwiftData
import CanvasCore

public struct SchemePair: Codable, Sendable {
    public let name: String
    public let value: Double   // 0.0–1.0 lower-bound fraction
    public init(name: String, value: Double) { self.name = name; self.value = value }
}

@Model
public final class CachedCourse {
    @Attribute(.unique) public var id: Int
    public var name: String
    public var courseCode: String
    public var applyGroupWeights: Bool
    public var gradingSchemeJSON: Data?
    public var hidden: Bool
    public var pinned: Bool
    public var sortIndex: Int
    public var accentColorHex: String?
    public var syllabusBody: String?
    public var removedAt: Date?

    public init(id: Int, name: String, courseCode: String, applyGroupWeights: Bool,
                gradingSchemeJSON: Data?, hidden: Bool = false, pinned: Bool = false,
                sortIndex: Int, accentColorHex: String? = nil,
                syllabusBody: String? = nil, removedAt: Date? = nil) {
        self.id = id; self.name = name; self.courseCode = courseCode
        self.applyGroupWeights = applyGroupWeights; self.gradingSchemeJSON = gradingSchemeJSON
        self.hidden = hidden; self.pinned = pinned; self.sortIndex = sortIndex
        self.accentColorHex = accentColorHex; self.syllabusBody = syllabusBody
        self.removedAt = removedAt
    }

    /// Sorted (name, percent-lower-bound) pairs; falls back to the BYUH default scale.
    public var gradingScale: [(String, Double)] {
        guard let data = gradingSchemeJSON,
              let pairs = try? JSONDecoder().decode([SchemePair].self, from: data),
              !pairs.isEmpty
        else { return byuhDefaultScale }
        return pairs.map { ($0.name, $0.value * 100) }.sorted { $0.1 > $1.1 }
    }
}

@Model
public final class CachedEnrollment {
    @Attribute(.unique) public var courseId: Int
    public var currentScore: Double?
    public var currentGrade: String?

    public init(courseId: Int, currentScore: Double?, currentGrade: String?) {
        self.courseId = courseId; self.currentScore = currentScore; self.currentGrade = currentGrade
    }
}

@Model
public final class CachedAssignmentGroup {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var name: String
    public var groupWeight: Double
    public var dropLowest: Int
    public var dropHighest: Int
    public var neverDrop: [Int]
    public var removedAt: Date?

    public init(id: Int, courseId: Int, name: String, groupWeight: Double,
                dropLowest: Int, dropHighest: Int, neverDrop: [Int], removedAt: Date? = nil) {
        self.id = id; self.courseId = courseId; self.name = name; self.groupWeight = groupWeight
        self.dropLowest = dropLowest; self.dropHighest = dropHighest
        self.neverDrop = neverDrop; self.removedAt = removedAt
    }
}

@Model
public final class CachedAssignment {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var groupId: Int
    public var name: String
    public var pointsPossible: Double?
    public var dueAt: Date?
    public var sortIndex: Int
    public var removedAt: Date?

    public init(id: Int, courseId: Int, groupId: Int, name: String,
                pointsPossible: Double?, dueAt: Date?, sortIndex: Int, removedAt: Date? = nil) {
        self.id = id; self.courseId = courseId; self.groupId = groupId; self.name = name
        self.pointsPossible = pointsPossible; self.dueAt = dueAt
        self.sortIndex = sortIndex; self.removedAt = removedAt
    }
}
