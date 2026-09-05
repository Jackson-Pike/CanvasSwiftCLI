import Foundation

// MARK: - Grouping mode

/// How the assignments board arranges its columns. Replaces the single-select
/// `AssignmentFilter` on the assignments screen with multi-column grouping.
public enum AssignmentGrouping: String, CaseIterable {
    case status, due, type

    /// Title-case label for the Group By control.
    public var label: String {
        switch self {
        case .status: return "Status"
        case .due:    return "Due date"
        case .type:   return "Category"
        }
    }
}

// MARK: - Due urgency

/// Urgency of an assignment's due date relative to `now`, measured in whole
/// calendar days. Centralizes the ad-hoc thresholds that were scattered across
/// `AgeCapsule` (≥5d) and `DueSoonStrip` (24h) into one shared classifier.
public enum DueUrgency: Equatable {
    case overdue    // due date is a past calendar day
    case today      // due today
    case soon       // 1–4 days out
    case upcoming   // 5–13 days out
    case later      // 14+ days out
    case none       // no due date
}

/// Whole calendar days from the start of `now`'s day to the start of `due`'s day.
/// Negative when `due` is before `now`. Calendar-aware so "Today" means the same
/// calendar day rather than a 24-hour window.
public func calendarDaysUntil(_ due: Date, from now: Date, calendar: Calendar = .current) -> Int {
    let startNow = calendar.startOfDay(for: now)
    let startDue = calendar.startOfDay(for: due)
    return calendar.dateComponents([.day], from: startNow, to: startDue).day ?? 0
}

public func dueUrgency(dueAt: Date?, now: Date, calendar: Calendar = .current) -> DueUrgency {
    guard let due = dueAt else { return .none }
    let days = calendarDaysUntil(due, from: now, calendar: calendar)
    if days < 0  { return .overdue }
    if days == 0 { return .today }
    if days <= 4 { return .soon }
    if days <= 13 { return .upcoming }
    return .later
}

// MARK: - Assignment kind

/// A short, human display kind derived from Canvas `submission_types`. Canvas has
/// no explicit "kind" field on an assignment, so the type is inferred (first match
/// wins, most specific first).
public func assignmentKind(submissionTypes: [String]) -> String {
    let types = Set(submissionTypes)
    if types.contains("online_quiz")       { return "Quiz" }
    if types.contains("discussion_topic")  { return "Discussion" }
    if types.contains("online_upload")     { return "Upload" }
    if types.contains("online_text_entry") { return "Text" }
    if types.contains("online_url")        { return "URL" }
    if types.contains("media_recording")   { return "Media" }
    if types.contains("external_tool")     { return "External" }
    if types.contains("on_paper")          { return "On paper" }
    if types.isEmpty || types == ["none"]  { return "No submission" }
    return "Other"
}

// MARK: - Board input / output

/// The minimal per-assignment facts the board bucketing needs. Kept free of any
/// SwiftData / persistence type so the grouping logic stays pure and testable.
public struct BoardAssignment: Equatable {
    public let id: Int
    public let dueAt: Date?
    /// Canvas assignment-group name (the "category", e.g. "Homework", "Exams").
    /// Drives the `.type` board; resolved from the assignment's group id upstream.
    public let category: String
    public let workflowState: String?
    public let score: Double?
    public let hasDraft: Bool

    public init(id: Int, dueAt: Date?, category: String,
                workflowState: String?, score: Double?, hasDraft: Bool) {
        self.id = id
        self.dueAt = dueAt
        self.category = category
        self.workflowState = workflowState
        self.score = score
        self.hasDraft = hasDraft
    }
}

/// A tint role the UI maps to a design token (kept as a semantic role rather than a
/// concrete `Color` so this stays in `CanvasCore`).
public enum BoardTint: String, Equatable {
    case neutral, muted, accent, positive, warning, danger
}

/// One board column: a stable id, a label, a tint role, and the assignment ids that
/// fall into it (already ordered for display — soonest due first, no-due last).
public struct BoardColumn: Equatable {
    public let id: String
    public let label: String
    public let tint: BoardTint
    public let assignmentIds: [Int]

    public init(id: String, label: String, tint: BoardTint, assignmentIds: [Int]) {
        self.id = id
        self.label = label
        self.tint = tint
        self.assignmentIds = assignmentIds
    }
}

// MARK: - Status classification

/// Mutually-exclusive board status for one assignment. Muted grades (graded with a
/// withheld score) count as `submitted`, matching `CanvasRepository.stream`.
public enum BoardStatus: Equatable {
    case graded, submitted, inProgress, notSubmitted
}

public func boardStatus(workflowState: String?, score: Double?, hasDraft: Bool) -> BoardStatus {
    if workflowState == "graded", score != nil { return .graded }
    if workflowState == "submitted" || workflowState == "pending_review"
        || (workflowState == "graded" && score == nil) { return .submitted }
    if hasDraft { return .inProgress }
    return .notSubmitted
}

// MARK: - Column builder

/// Buckets `assignments` into ordered columns for the given grouping. Each assignment
/// lands in exactly one column; within a column, items are sorted soonest-due first
/// (no-due last). `status` and `due` produce a fixed set of columns (some may be empty,
/// which the UI renders as an empty state); `type` produces only the Canvas
/// assignment-group categories present, ordered alphabetically by name.
public func boardColumns(for grouping: AssignmentGrouping,
                         assignments: [BoardAssignment],
                         now: Date,
                         calendar: Calendar = .current) -> [BoardColumn] {
    func sortByDue(_ items: [BoardAssignment]) -> [Int] {
        items.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
             .map(\.id)
    }

    switch grouping {
    case .status:
        let specs: [(String, String, BoardTint, BoardStatus)] = [
            ("notSubmitted", "Not submitted", .muted,    .notSubmitted),
            ("inProgress",   "In progress",   .accent,   .inProgress),
            ("submitted",    "Submitted",     .warning,  .submitted),
            ("graded",       "Graded",        .neutral,  .graded),
        ]
        return specs.map { id, label, tint, status in
            let items = assignments.filter {
                boardStatus(workflowState: $0.workflowState, score: $0.score, hasDraft: $0.hasDraft) == status
            }
            return BoardColumn(id: id, label: label, tint: tint, assignmentIds: sortByDue(items))
        }

    case .due:
        func bucket(_ a: BoardAssignment) -> String {
            guard let due = a.dueAt else { return "later" }
            let days = calendarDaysUntil(due, from: now, calendar: calendar)
            if days < 0  { return "closed" }
            if days <= 6 { return "week" }
            if days <= 13 { return "next" }
            return "later"
        }
        let specs: [(String, String, BoardTint)] = [
            ("week",   "This week", .danger),
            ("next",   "Next week", .warning),
            ("later",  "Later",     .accent),
            ("closed", "Closed",    .muted),
        ]
        return specs.map { id, label, tint in
            let items = assignments.filter { bucket($0) == id }
            return BoardColumn(id: id, label: label, tint: tint, assignmentIds: sortByDue(items))
        }

    case .type:
        var byCategory: [String: [BoardAssignment]] = [:]
        for a in assignments {
            byCategory[a.category, default: []].append(a)
        }
        let present = byCategory.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return present.map { category in
            BoardColumn(id: category, label: category, tint: .neutral,
                        assignmentIds: sortByDue(byCategory[category] ?? []))
        }
    }
}
