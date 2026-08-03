import SwiftUI
import CanvasCore

// MARK: - AssignmentFilterChips

/// Segmented row of filter chips over `AssignmentFilter`. Active chip is
/// `inkPrimary` text on a low-opacity `inkPrimary` fill; inactive chips are a
/// bare `canvasHairline` outline.
public struct AssignmentFilterChips: View {
    @Binding private var selected: AssignmentFilter

    public init(selected: Binding<AssignmentFilter>) {
        self._selected = selected
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(AssignmentFilter.allCases, id: \.rawValue) { filter in
                Button {
                    selected = filter
                } label: {
                    chip(for: filter)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chip(for filter: AssignmentFilter) -> some View {
        let isActive = filter == selected
        return Text(filter.rawValue)
            .font(.system(size: 10.5, weight: isActive ? .bold : .medium))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(isActive ? Color.inkPrimary : Color.inkTertiary)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(isActive ? Color.inkPrimary.opacity(0.09) : Color.clear, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color.clear : Color.canvasHairline, lineWidth: 1)
            )
            .contentShape(Capsule())
    }
}

// MARK: - AssignmentListRow

/// One assignment in the assignments-tab list. Follows `LedgerRowView`'s
/// grammar: 1px `canvasRule` divider on top, name + `inkTertiary` subtitle on
/// the left, a right-aligned score or state badge, and an `inkPrimary`@4%
/// fill when selected (the same tint `LedgerRowView` uses for hover).
public struct AssignmentListRow: View {
    private let name: String
    private let dueAt: Date?
    private let pointsPossible: Double?
    private let score: Double?
    private let workflowState: String?
    private let isMissing: Bool
    private let isSelected: Bool
    private let onTap: () -> Void

    @State private var isHovering = false

    public init(
        name: String,
        dueAt: Date?,
        pointsPossible: Double?,
        score: Double?,
        workflowState: String?,
        isMissing: Bool,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) {
        self.name = name
        self.dueAt = dueAt
        self.pointsPossible = pointsPossible
        self.score = score
        self.workflowState = workflowState
        self.isMissing = isMissing
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.canvasRule)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.inkTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingBadge
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
        }
        .background(isSelected ? Color.inkPrimary.opacity(0.04) : Color.clear)
        .background(isHovering && !isSelected ? Color.inkPrimary.opacity(0.02) : Color.clear)
        .contentShape(Rectangle())
    }

    // MARK: Subtitle

    private var subtitle: String {
        var parts: [String] = []
        if let dueAt {
            parts.append("due " + AssignmentComponentFormat.shortDate.string(from: dueAt))
        } else {
            parts.append("no due date")
        }
        if let pointsPossible {
            parts.append(AssignmentComponentFormat.points(pointsPossible) + " pts")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Trailing badge

    @ViewBuilder
    private var trailingBadge: some View {
        if isMissing {
            Text("Missing")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.lostMissing)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.lostMissing.opacity(0.14), in: Capsule())
        } else if let score, let percent {
            VStack(alignment: .trailing, spacing: 1) {
                Text(scoreText(score))
                    .font(.mono(13, weight: .bold))
                    .foregroundStyle(Color.letterGradeColor(letterGrade(for: percent, scale: byuhDefaultScale)))
                Text(String(format: "%.0f%%", percent))
                    .font(.mono(9.5))
                    .foregroundStyle(Color.inkTertiary)
            }
        } else if let score {
            Text(scoreText(score))
                .font(.mono(13, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
        } else {
            Text(stateLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.inkTertiary)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.inkPrimary.opacity(0.05), in: Capsule())
        }
    }

    private var percent: Double? {
        guard let score, let pointsPossible, pointsPossible > 0 else { return nil }
        return score / pointsPossible * 100
    }

    private func scoreText(_ score: Double) -> String {
        if let pointsPossible {
            return AssignmentComponentFormat.points(score) + "/" + AssignmentComponentFormat.points(pointsPossible)
        }
        return AssignmentComponentFormat.points(score)
    }

    private var stateLabel: String {
        switch workflowState {
        case "submitted": return "Submitted"
        case "pending_review": return "In review"
        case "graded": return "Graded"
        case "unsubmitted", nil: return "Not submitted"
        default: return workflowState?.replacingOccurrences(of: "_", with: " ").capitalized ?? "—"
        }
    }
}

// MARK: - RubricTable

/// One row per `RubricLine`: criterion on the left, `earned/possible` in mono
/// on the right, `ratingLabel` as an `inkTertiary` caption beneath, and the
/// instructor comment (when present) as an indented `inkSecondary` line.
public struct RubricTable: View {
    private let lines: [RubricLine]

    public init(lines: [RubricLine]) {
        self.lines = lines
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RUBRIC")
                .font(.sectionLabel)
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkTertiary)
                .padding(.bottom, 6)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                RubricTableRow(line: line)
            }
        }
    }
}

private struct RubricTableRow: View {
    let line: RubricLine

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.canvasRule)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(line.criterionDescription)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(pointsText)
                        .font(.mono(12.5, weight: .bold))
                        .foregroundStyle(line.earnedPoints == nil ? Color.inkTertiary : Color.inkPrimary)
                }

                if let ratingLabel = line.ratingLabel, !ratingLabel.isEmpty {
                    Text(ratingLabel)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.inkTertiary)
                }

                if let comment = line.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.leading, 12)
                        .padding(.top, 1)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var pointsText: String {
        let earned = line.earnedPoints.map { AssignmentComponentFormat.points($0) } ?? "—"
        return earned + "/" + AssignmentComponentFormat.points(line.possiblePoints)
    }
}

// MARK: - InstructorCommentRow

/// A single instructor comment. Reuses `RecentFeedbackPanel`'s comment-row
/// grammar — initials circle, bold author, quoted comment beneath.
public struct InstructorCommentRow: View {
    private let authorName: String
    private let comment: String
    private let createdAt: Date?

    public init(authorName: String, comment: String, createdAt: Date?) {
        self.authorName = authorName
        self.comment = comment
        self.createdAt = createdAt
    }

    public var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.canvasRule)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 11) {
                Circle()
                    .fill(Color.inkPrimary.opacity(0.10))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color.inkSecondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    (
                        Text(authorName).fontWeight(.bold).foregroundStyle(Color.inkPrimary)
                        + Text(createdAt.map { " · " + AssignmentComponentFormat.shortDate.string(from: $0) } ?? "")
                            .foregroundStyle(Color.inkTertiary)
                    )
                    .font(.system(size: 12))

                    Text("\u{201C}\(comment)\u{201D}")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(nil)
                }
            }
            .padding(.vertical, 9)
        }
        .contentShape(Rectangle())
    }

    private var initials: String {
        let parts = authorName
            .split(separator: " ")
            .filter { $0.first?.isLetter == true }
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Formatting helpers

enum AssignmentComponentFormat {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// Trims a trailing `.0` so whole-point values read as `20` rather than `20.0`.
    static func points(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Previews

#if DEBUG
private struct AssignmentComponentsPreview: View {
    @State private var filter: AssignmentFilter = .upcoming

    private var due: Date { Date(timeIntervalSince1970: 1_772_000_000) }

    private var rubricLines: [RubricLine] {
        [
            RubricLine(
                criterionDescription: "Thesis clarity",
                possiblePoints: 20,
                earnedPoints: 18,
                ratingLabel: "Proficient",
                comment: "Strong claim, but state it in the first paragraph."
            ),
            RubricLine(
                criterionDescription: "Use of primary sources",
                possiblePoints: 25,
                earnedPoints: 25,
                ratingLabel: "Exemplary",
                comment: nil
            ),
            RubricLine(
                criterionDescription: "Mechanics and citation format",
                possiblePoints: 15,
                earnedPoints: nil,
                ratingLabel: nil,
                comment: nil
            ),
            RubricLine(
                criterionDescription: "Peer response quality",
                possiblePoints: 10,
                earnedPoints: nil,
                ratingLabel: "Not yet scored",
                comment: "Waiting on your second reply."
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AssignmentFilterChips(selected: $filter)

            VStack(spacing: 0) {
                AssignmentListRow(
                    name: "Essay 2 — Rhetoric and Persuasion",
                    dueAt: due,
                    pointsPossible: 50,
                    score: 47,
                    workflowState: "graded",
                    isMissing: false,
                    isSelected: true,
                    onTap: {}
                )
                AssignmentListRow(
                    name: "Problem Set 6",
                    dueAt: due,
                    pointsPossible: 40,
                    score: 28,
                    workflowState: "graded",
                    isMissing: false,
                    isSelected: false,
                    onTap: {}
                )
                AssignmentListRow(
                    name: "Reading Journal 4",
                    dueAt: due,
                    pointsPossible: 15,
                    score: nil,
                    workflowState: "submitted",
                    isMissing: false,
                    isSelected: false,
                    onTap: {}
                )
                AssignmentListRow(
                    name: "Lab Report 3: Titration Analysis",
                    dueAt: due,
                    pointsPossible: 50,
                    score: nil,
                    workflowState: "unsubmitted",
                    isMissing: true,
                    isSelected: false,
                    onTap: {}
                )
                AssignmentListRow(
                    name: "Final Portfolio",
                    dueAt: nil,
                    pointsPossible: nil,
                    score: nil,
                    workflowState: nil,
                    isMissing: false,
                    isSelected: false,
                    onTap: {}
                )
            }

            RubricTable(lines: rubricLines)

            VStack(spacing: 0) {
                InstructorCommentRow(
                    authorName: "Prof. Pike",
                    comment: "Excellent synthesis of primary sources; watch your topic sentences.",
                    createdAt: due
                )
                InstructorCommentRow(
                    authorName: "TA Nguyen",
                    comment: "Resubmit the appendix when you get a chance.",
                    createdAt: nil
                )
            }
        }
        .padding(16)
        .frame(width: 460)
        .background(Color.canvasBG)
    }
}

#Preview("Assignment Components - Light") {
    AssignmentComponentsPreview()
        .preferredColorScheme(.light)
}

#Preview("Assignment Components - Dark") {
    AssignmentComponentsPreview()
        .preferredColorScheme(.dark)
}
#endif
