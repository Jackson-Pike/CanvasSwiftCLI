import Foundation
import CanvasCore
import CanvasData

@MainActor
final class CourseDetailViewModel: ObservableObject {
    let course: Course
    @Published var calculator: GradeCalculator?
    @Published var groupInfo: [Int: GroupInfo] = [:]
    @Published var allItems: [GradedItem] = []
    @Published var streamItems: [StreamItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private var lastFetchedAt: Date?
    private let cacheTTL: TimeInterval = 5 * 60

    init(course: Course) { self.course = course }

    var gradingScale: [(String, Double)] { course.gradingScale }

    func fetch(client: APIClient, force: Bool = false) async {
        if !force,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < cacheTTL,
           calculator != nil {
            return
        }
        isLoading = true
        error = nil
        do {
            async let groups = client.assignmentGroups(courseId: course.id)
            async let subs   = client.submissions(courseId: course.id)
            let (fetchedGroups, fetchedSubs) = try await (groups, subs)

            let info = Dictionary(uniqueKeysWithValues: fetchedGroups.map { g in
                (g.id, GroupInfo(name: g.name, weight: g.groupWeight,
                                 dropLowest:  g.rules?.dropLowest  ?? 0,
                                 dropHighest: g.rules?.dropHighest ?? 0,
                                 neverDrop:   Set(g.rules?.neverDrop ?? [])))
            })
            groupInfo = info
            let items = buildGradedItems(groups: fetchedGroups, submissions: fetchedSubs)
            allItems  = items
            calculator = GradeCalculator(items: items, groups: info,
                                          weighted: course.applyAssignmentGroupWeights ?? false,
                                          gradingScale: gradingScale)
            streamItems = buildStream(groups: fetchedGroups, submissions: fetchedSubs)
            lastFetchedAt = Date()
        } catch let e as APIError { error = e.description }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }

    private func buildStream(groups: [AssignmentGroup], submissions: [Submission]) -> [StreamItem] {
        let iso = ISO8601DateFormatter()
        let now = Date()

        let allAssignments: [StreamAssignment] = groups.flatMap { g in
            g.assignments.map { a in
                StreamAssignment(
                    id: a.id,
                    name: a.name,
                    pointsPossible: a.pointsPossible,
                    dueAt: a.dueAt.flatMap { iso.date(from: $0) }
                )
            }
        }
        let assignmentById = Dictionary(uniqueKeysWithValues: allAssignments.map { ($0.id, $0) })
        let subById = Dictionary(uniqueKeysWithValues: submissions.map { ($0.assignmentId, $0) })

        // Submitted but not yet graded
        let awaitingGrade: [StreamItem] = submissions
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
        let recentlyGraded: [StreamItem] = submissions
            .filter { $0.workflowState == "graded" && $0.score != nil }
            .sorted { lhs, rhs in
                let lDate = lhs.gradedAt.flatMap { iso.date(from: $0) } ?? .distantPast
                let rDate = rhs.gradedAt.flatMap { iso.date(from: $0) } ?? .distantPast
                return lDate > rDate
            }
            .prefix(2)
            .compactMap { sub -> StreamItem? in
                guard let a = assignmentById[sub.assignmentId] else { return nil }
                let gradedDate = sub.gradedAt.flatMap { iso.date(from: $0) }
                return StreamItem(assignment: a, kind: .recentlyGraded(
                    score: sub.score,
                    possible: a.pointsPossible,
                    gradedAt: gradedDate
                ))
            }

        // Recent instructor feedback: non-self comments, most recent 3
        let recentFeedback: [StreamItem] = submissions
            .flatMap { sub -> [(StreamItem)] in
                guard let a = assignmentById[sub.assignmentId],
                      let comments = sub.submissionComments else { return [] }
                return comments
                    .filter { $0.authorId != sub.userId }
                    .compactMap { c -> StreamItem? in
                        let date = c.createdAt.flatMap { iso.date(from: $0) }
                        return StreamItem(assignment: a, kind: .feedback(
                            authorName: c.authorName,
                            comment: c.comment,
                            createdAt: date
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
