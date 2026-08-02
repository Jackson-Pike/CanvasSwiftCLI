import Foundation
import CanvasCore

/// Inputs for `GradeCalculator`, assembled from cached store rows for a course.
public struct CalculatorInputs {
    public let items: [GradedItem]
    public let groups: [Int: GroupInfo]
    public let weighted: Bool
    public let scale: [(String, Double)]
}

public struct StreamAssignment: Sendable {
    public let id: Int
    public let name: String
    public let pointsPossible: Double?
    public let dueAt: Date?

    public init(id: Int, name: String, pointsPossible: Double?, dueAt: Date?) {
        self.id = id
        self.name = name
        self.pointsPossible = pointsPossible
        self.dueAt = dueAt
    }
}

public struct StreamItem: Sendable {
    public enum Kind: Sendable {
        case awaitingGrade
        case upcoming(due: Date)
        case recentlyGraded(score: Double?, possible: Double?, gradedAt: Date?)
        case feedback(authorName: String, comment: String, createdAt: Date?)
    }

    public let assignment: StreamAssignment
    public let kind: Kind

    public init(assignment: StreamAssignment, kind: Kind) {
        self.assignment = assignment
        self.kind = kind
    }
}

extension CanvasRepository {

    /// Mirrors `buildGradedItems` (CanvasCore/GradeCalculator.swift) over cached rows.
    public func calculatorInputs(courseId: Int) throws -> CalculatorInputs? {
        guard let course = try course(id: courseId) else { return nil }
        let subs = try submissions(courseId: courseId)
        let scoreByAssignment = Dictionary(subs.map { ($0.assignmentId, $0.score) },
                                            uniquingKeysWith: { first, _ in first })
        let items: [GradedItem] = try assignments(courseId: courseId).compactMap { a in
            guard let pts = a.pointsPossible else { return nil }
            return GradedItem(assignmentId: a.id, name: a.name, groupId: a.groupId,
                              pointsPossible: pts, earnedPoints: scoreByAssignment[a.id] ?? nil)
        }
        let groupInfo = Dictionary(uniqueKeysWithValues: try assignmentGroups(courseId: courseId).map {
            ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight,
                              dropLowest: $0.dropLowest, dropHighest: $0.dropHighest,
                              neverDrop: Set($0.neverDrop)))
        })
        return CalculatorInputs(items: items, groups: groupInfo,
                                weighted: course.applyGroupWeights, scale: course.gradingScale)
    }

    /// Ports `CourseDetailViewModel.buildStream` 1:1 over cached rows (dates are already `Date`).
    public func stream(courseId: Int, now: Date = .init()) throws -> [StreamItem] {
        let cachedAssignments = try assignments(courseId: courseId)
        let cachedSubmissions = try submissions(courseId: courseId)

        let allAssignments: [StreamAssignment] = cachedAssignments.map { a in
            StreamAssignment(id: a.id, name: a.name, pointsPossible: a.pointsPossible, dueAt: a.dueAt)
        }
        let assignmentById = Dictionary(uniqueKeysWithValues: allAssignments.map { ($0.id, $0) })
        // assignmentId is not unique across submission rows (nothing in the write path
        // enforces one row per assignment), so a duplicate must not trap. Matches the
        // uniquing already used in `calculatorInputs`.
        let subById = Dictionary(cachedSubmissions.map { ($0.assignmentId, $0) },
                                 uniquingKeysWith: { first, _ in first })

        var commentsByAssignment: [Int: [CachedComment]] = [:]
        for a in cachedAssignments {
            commentsByAssignment[a.id] = try comments(assignmentId: a.id)
        }

        // Submitted but not yet graded (includes muted grades: graded with score withheld)
        let awaitingGrade: [StreamItem] = cachedSubmissions
            .filter {
                $0.workflowState == "submitted" ||
                $0.workflowState == "pending_review" ||
                ($0.workflowState == "graded" && $0.score == nil)
            }
            .compactMap { sub -> StreamItem? in
                guard let a = assignmentById[sub.assignmentId] else { return nil }
                return StreamItem(assignment: a, kind: .awaitingGrade)
            }
            .prefix(2)
            .map { $0 }

        // Upcoming: due in the future, not yet submitted
        let upcoming: [StreamItem] = allAssignments
            .filter { a in
                guard let due = a.dueAt, due > now else { return false }
                let sub = subById[a.id]
                return sub == nil || sub?.workflowState == "unsubmitted"
            }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            .prefix(2)
            .map { a in StreamItem(assignment: a, kind: .upcoming(due: a.dueAt!)) }

        // Recently graded: last 2 by gradedAt
        let recentlyGraded: [StreamItem] = cachedSubmissions
            .filter { $0.workflowState == "graded" && $0.score != nil }
            .sorted { lhs, rhs in
                (lhs.gradedAt ?? .distantPast) > (rhs.gradedAt ?? .distantPast)
            }
            .prefix(2)
            .compactMap { sub -> StreamItem? in
                guard let a = assignmentById[sub.assignmentId] else { return nil }
                return StreamItem(assignment: a, kind: .recentlyGraded(
                    score: sub.score,
                    possible: a.pointsPossible,
                    gradedAt: sub.gradedAt
                ))
            }

        // Recent instructor feedback: non-self comments, most recent 3
        let recentFeedback: [StreamItem] = cachedSubmissions
            .flatMap { sub -> [StreamItem] in
                guard let a = assignmentById[sub.assignmentId] else { return [] }
                let subComments = (commentsByAssignment[sub.assignmentId] ?? [])
                    .filter { $0.submissionId == sub.id && $0.authorId != sub.userId }
                return subComments.map { c in
                    StreamItem(assignment: a, kind: .feedback(
                        authorName: c.authorName,
                        comment: c.body,
                        createdAt: c.createdAt
                    ))
                }
            }
            .sorted { lhs, rhs in
                if case .feedback(_, _, let lDate) = lhs.kind,
                   case .feedback(_, _, let rDate) = rhs.kind {
                    return (lDate ?? .distantPast) > (rDate ?? .distantPast)
                }
                return false
            }
            .prefix(3)
            .map { $0 }

        return awaitingGrade + upcoming + recentlyGraded + recentFeedback
    }
}
