import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

// MARK: - Presentation helpers (shared by the docked preview pane and the full-screen page)

enum AssignmentDetailFormat {
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// Trims a trailing `.0` so whole-point values read as `20` rather than `20.0`.
    static func points(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// Status pill label + tint for a selected assignment. Graded appends the score.
func assignmentStatusPill(_ status: BoardStatus, score: Double?, pointsPossible: Double?) -> (label: String, tint: BoardTint) {
    switch status {
    case .graded:
        if let score {
            let possible = pointsPossible.map { " / " + AssignmentDetailFormat.points($0) } ?? ""
            return ("Graded · " + AssignmentDetailFormat.points(score) + possible, .neutral)
        }
        return ("Graded", .neutral)
    case .submitted:    return ("Submitted", .warning)
    case .inProgress:   return ("Draft saved", .accent)
    case .notSubmitted: return ("Not submitted", .muted)
    }
}

/// Call-to-action label for the docked pane's button, by status.
func assignmentCTALabel(_ status: BoardStatus) -> String {
    switch status {
    case .graded:       return "View feedback"
    case .submitted:    return "View submission"
    case .inProgress:   return "Continue draft"
    case .notSubmitted: return "Start assignment"
    }
}

func assignmentPointsPill(_ pointsPossible: Double?) -> String {
    guard let pointsPossible else { return "— pts" }
    return AssignmentDetailFormat.points(pointsPossible) + " pts"
}

/// "due Sep 9 · in 5d" / "closed Sep 9" / "no due date".
func assignmentDueDescription(dueAt: Date?, now: Date, status: BoardStatus) -> String {
    guard let due = dueAt else { return "no due date" }
    let dateStr = AssignmentDetailFormat.mediumDate.string(from: due)
    if status == .graded { return "closed " + dateStr }
    let days = calendarDaysUntil(due, from: now)
    let suffix = days == 0 ? " · today" : days > 0 ? " · in \(days)d" : " · \(abs(days))d late"
    return "due " + dateStr + suffix
}

// MARK: - Shared header

/// Kind + due eyebrow, title, and the status / points / grade-weight pills.
struct AssignmentDetailHeader: View {
    let assignment: CachedAssignment
    let status: BoardStatus
    let score: Double?
    let gradeWeightText: String?
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text(assignmentKind(submissionTypes: assignment.submissionTypes))
                Circle().fill(Color.inkQuaternary.opacity(0.6)).frame(width: 3, height: 3)
                Text(assignmentDueDescription(dueAt: assignment.dueAt, now: now, status: status))
            }
            .font(.mono(10.5))
            .foregroundStyle(Color.inkTertiary)

            Text(assignment.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            let pill = assignmentStatusPill(status, score: score, pointsPossible: assignment.pointsPossible)
            DetailStatusPills(statusLabel: pill.label, statusTint: pill.tint,
                              pointsText: assignmentPointsPill(assignment.pointsPossible),
                              gradeWeightText: gradeWeightText)
        }
    }
}

// MARK: - Shared read-only sections (Description · Rubric · Related)

struct AssignmentReadonlySections: View {
    let assignment: CachedAssignment
    let submission: CachedSubmission?
    let relatedModules: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                DetailSectionHeader("Description")
                RichTextView(html: assignment.descriptionHTML ?? "<p>No description.</p>")
            }

            let criteria = assignment.rubric
            if !criteria.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    DetailSectionHeader("Rubric",
                                        trailing: assignment.pointsPossible.map { AssignmentDetailFormat.points($0) + " pts" })
                    RubricTable(lines: formatRubricAssessment(criteria: criteria,
                                                              assessment: submission?.rubricAssessment ?? [:]))
                }
            }

            if !relatedModules.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    DetailSectionHeader("Related in this course")
                    RelatedModulesChips(modules: relatedModules)
                }
            }
        }
    }
}
