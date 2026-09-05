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

    /// A board column resolved back to the app's `Row`s, ready for the view to render.
    struct BoardColumnRows: Identifiable {
        let id: String
        let label: String
        let tint: BoardTint
        let meta: String?
        let rows: [Row]
        var count: Int { rows.count }
    }

    let courseId: Int
    @Published var grouping: AssignmentGrouping = .status
    @Published var rows: [Row] = []
    @Published var selectedAssignmentId: Int?
    @Published var comments: [CachedComment] = []
    @Published var relatedModuleNames: [String] = []
    @Published var ledger = PointsLedger(earned: 0, lost: 0, inPlay: 0, total: 0)
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?

    /// AssignmentIds that have a locally-saved (unsent) draft — feeds the "In progress" column.
    private var draftIds: Set<Int> = []

    /// Assignment-group id → Canvas group name (the "category"), used to bucket the Type board.
    private var groupNames: [Int: String] = [:]

    init(courseId: Int) {
        self.courseId = courseId
    }

    /// Columns for the current grouping, each carrying its resolved rows. Built from the
    /// pure `boardColumns(...)` classifier in CanvasCore.
    var boardColumns: [BoardColumnRows] {
        let now = Date()
        let boardAssignments = rows.map { r in
            BoardAssignment(id: r.assignment.id,
                            dueAt: r.assignment.dueAt,
                            category: groupNames[r.assignment.groupId] ?? "Uncategorized",
                            workflowState: r.submission?.workflowState,
                            score: r.submission?.score,
                            hasDraft: draftIds.contains(r.assignment.id))
        }
        let cols = CanvasCore.boardColumns(for: grouping, assignments: boardAssignments, now: now)
        let rowById = Dictionary(uniqueKeysWithValues: rows.map { ($0.assignment.id, $0) })
        return cols.map { col in
            BoardColumnRows(id: col.id, label: col.label, tint: col.tint,
                            meta: columnMeta(id: col.id),
                            rows: col.assignmentIds.compactMap { rowById[$0] })
        }
    }

    /// Number of assignments due in the current calendar week window (0–6 days out).
    var dueThisWeek: Int {
        let now = Date()
        return rows.filter { r in
            guard let due = r.assignment.dueAt else { return false }
            let days = calendarDaysUntil(due, from: now)
            return days >= 0 && days <= 6
        }.count
    }

    /// Short editorial meta for a status column; other groupings carry none.
    private func columnMeta(id: String) -> String? {
        guard grouping == .status else { return nil }
        switch id {
        case "notSubmitted": return "backlog"
        case "inProgress":   return "draft"
        case "submitted":    return "awaiting"
        case "graded":       return "done"
        default:             return nil
        }
    }

    var selectedRow: Row? {
        selectedAssignmentId.flatMap { id in rows.first { $0.assignment.id == id } }
    }

    /// Board status for a row, joining the row's submission with its local draft state.
    func boardStatus(for row: Row) -> BoardStatus {
        CanvasCore.boardStatus(workflowState: row.submission?.workflowState,
                               score: row.submission?.score,
                               hasDraft: draftIds.contains(row.assignment.id))
    }

    /// This assignment's points as a share of total course points — "N% of course".
    /// nil when there are no gradable points yet.
    func gradeWeightText(for row: Row) -> String? {
        guard let points = row.assignment.pointsPossible, ledger.total > 0 else { return nil }
        return "\(Int((points / ledger.total * 100).rounded()))% of course"
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
        relatedModuleNames = (try? session.repository.modulesContaining(assignmentId: assignmentId, courseId: courseId))?
            .map(\.name) ?? []
    }

    private func readFromStore(_ session: AppSession) {
        let assignments = (try? session.repository.assignments(courseId: courseId)) ?? []
        let submissions = (try? session.repository.submissions(courseId: courseId)) ?? []
        let byAssignment = Dictionary(submissions.map { ($0.assignmentId, $0) },
                                      uniquingKeysWith: { first, _ in first })
        rows = assignments.map { Row(assignment: $0, submission: byAssignment[$0.id]) }
        groupNames = Dictionary((try? session.repository.assignmentGroups(courseId: courseId))?
            .map { ($0.id, $0.name) } ?? [], uniquingKeysWith: { first, _ in first })
        draftIds = Set((try? session.repository.submissionDrafts(courseId: courseId))?.map(\.assignmentId) ?? [])
        if let inputs = try? session.repository.calculatorInputs(courseId: courseId) {
            ledger = GradeCalculator(items: inputs.items, groups: inputs.groups,
                                     weighted: inputs.weighted, gradingScale: inputs.scale).pointsLedger()
        }
        lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "submissions", scopeId: "\(courseId)")
        if let selectedAssignmentId {
            comments = (try? session.repository.comments(assignmentId: selectedAssignmentId)) ?? []
        }
    }
}
