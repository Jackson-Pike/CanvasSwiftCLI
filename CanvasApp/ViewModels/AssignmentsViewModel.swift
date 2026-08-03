import Foundation
import CanvasCore
import CanvasData

@MainActor
final class AssignmentsViewModel: ObservableObject {
    struct Row: Identifiable {
        let assignment: CachedAssignment
        let submission: CachedSubmission?
        var id: Int { assignment.id }
    }

    let courseId: Int
    @Published var filter: AssignmentFilter = .upcoming
    @Published var rows: [Row] = []
    @Published var selectedAssignmentId: Int?
    @Published var comments: [CachedComment] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?

    init(courseId: Int) {
        self.courseId = courseId
    }

    var filteredRows: [Row] {
        let now = Date()
        return rows.filter {
            assignmentMatchesFilter(filter,
                                    dueAt: $0.assignment.dueAt,
                                    workflowState: $0.submission?.workflowState,
                                    score: $0.submission?.score,
                                    missingFlag: $0.submission?.missing,
                                    now: now)
        }
    }

    var selectedRow: Row? {
        selectedAssignmentId.flatMap { id in rows.first { $0.assignment.id == id } }
    }

    /// Comments authored by anyone other than the student themselves. The student's own
    /// id comes off their submission row — `AppSession` doesn't carry a profile.
    var instructorComments: [CachedComment] {
        guard let studentId = selectedRow?.submission?.userId else { return comments }
        return comments.filter { $0.authorId != studentId }
    }

    func load(session: AppSession, force: Bool = false) async {
        readFromStore(session)                       // instant render from disk
        guard session.hasCredentials else { return }
        isLoading = rows.isEmpty                     // skeleton only when cold
        error = nil
        error = await session.refresh(.course(courseId), force: force)
        readFromStore(session)                       // re-read after sync
        isLoading = false
    }

    func select(_ assignmentId: Int, session: AppSession) {
        selectedAssignmentId = assignmentId
        comments = (try? session.repository.comments(assignmentId: assignmentId)) ?? []
    }

    private func readFromStore(_ session: AppSession) {
        let assignments = (try? session.repository.assignments(courseId: courseId)) ?? []
        let submissions = (try? session.repository.submissions(courseId: courseId)) ?? []
        let byAssignment = Dictionary(submissions.map { ($0.assignmentId, $0) },
                                      uniquingKeysWith: { first, _ in first })
        rows = assignments.map { Row(assignment: $0, submission: byAssignment[$0.id]) }
        lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "submissions", scopeId: "\(courseId)")
        if let selectedAssignmentId {
            comments = (try? session.repository.comments(assignmentId: selectedAssignmentId)) ?? []
        }
    }
}
