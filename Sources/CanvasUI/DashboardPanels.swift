import SwiftUI

// MARK: - Value types

/// A single row in `AwaitingGradePanel`. `CanvasUI` does not depend on `CanvasData`;
/// the app layer maps its own `StreamItem`s into these.
public struct AwaitingRow: Identifiable {
    public let id: Int
    public let dotColor: Color
    public let title: String
    public let subtitle: String
    public let ageDays: Int
    public let onTap: () -> Void

    public init(
        id: Int,
        dotColor: Color,
        title: String,
        subtitle: String,
        ageDays: Int,
        onTap: @escaping () -> Void
    ) {
        self.id = id
        self.dotColor = dotColor
        self.title = title
        self.subtitle = subtitle
        self.ageDays = ageDays
        self.onTap = onTap
    }
}

/// A single row in `RecentFeedbackPanel`.
public struct FeedbackRow: Identifiable {
    public let id: Int
    public let initials: String
    public let tint: Color
    public let author: String
    public let context: String
    public let comment: String
    public let onTap: () -> Void

    public init(
        id: Int,
        initials: String,
        tint: Color,
        author: String,
        context: String,
        comment: String,
        onTap: @escaping () -> Void
    ) {
        self.id = id
        self.initials = initials
        self.tint = tint
        self.author = author
        self.context = context
        self.comment = comment
        self.onTap = onTap
    }
}

// MARK: - AgeCapsule

/// Small pill showing how many days an item has been awaiting grade. Turns
/// warm (`lostMissing`) once it's been sitting for 5+ days — that aging
/// signal is the whole point of the panel.
public struct AgeCapsule: View {
    private let days: Int

    public init(days: Int) {
        self.days = days
    }

    private var isAged: Bool { days >= 5 }

    public var body: some View {
        Text("\(days)d")
            .font(.mono(10.5))
            .foregroundStyle(isAged ? Color.lostMissing : Color.inkPrimary)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                (isAged ? Color.lostMissing.opacity(0.14) : Color.inkPrimary.opacity(0.06)),
                in: Capsule()
            )
    }
}

// MARK: - AwaitingGradePanel

public struct AwaitingGradePanel: View {
    private let rows: [AwaitingRow]
    private let heldBackNote: String?

    public init(rows: [AwaitingRow], heldBackNote: String?) {
        self.rows = rows
        self.heldBackNote = heldBackNote
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Awaiting Grade")
                    .font(.sectionLabel)
                    .foregroundStyle(Color.inkTertiary)
                Text("\(rows.count)")
                    .font(.mono(10.5))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.bottom, 6)

            ForEach(rows) { row in
                Button(action: row.onTap) {
                    AwaitingGradeRowView(row: row)
                }
                .buttonStyle(.plain)
            }

            if let heldBackNote {
                Text(heldBackNote)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.inkTertiary)
                    .padding(.top, 6)
            }
        }
    }
}

private struct AwaitingGradeRowView: View {
    let row: AwaitingRow

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.canvasRule)
                .frame(height: 1)

            HStack(spacing: 8) {
                Circle()
                    .fill(row.dotColor)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(row.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.inkTertiary)
                }

                Spacer(minLength: 8)

                AgeCapsule(days: row.ageDays)
            }
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - RecentFeedbackPanel

public struct RecentFeedbackPanel: View {
    private let rows: [FeedbackRow]

    public init(rows: [FeedbackRow]) {
        self.rows = rows
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                Button(action: row.onTap) {
                    RecentFeedbackRowView(row: row)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RecentFeedbackRowView: View {
    let row: FeedbackRow

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.canvasRule)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 11) {
                Circle()
                    .fill(row.tint.opacity(0.18))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text(row.initials)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(row.tint)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    (
                        Text(row.author).fontWeight(.bold).foregroundStyle(Color.inkPrimary)
                        + Text(" · " + row.context).foregroundStyle(Color.inkTertiary)
                    )
                    .font(.system(size: 12))

                    Text("\u{201C}\(row.comment)\u{201D}")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(nil)
                }
            }
            .padding(.vertical, 9)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#if DEBUG
private struct DashboardPanelsPreview: View {
    var awaitingRows: [AwaitingRow] {
        [
            AwaitingRow(
                id: 1,
                dotColor: .accentHypothetical,
                title: "Essay 2 — Rhetoric and Persuasion",
                subtitle: "submitted Feb 24 · 25 pts",
                ageDays: 2,
                onTap: {}
            ),
            AwaitingRow(
                id: 2,
                dotColor: .lostMissing,
                title: "Lab Report 4: Titration Analysis and Error Sources",
                subtitle: "submitted Feb 18 · 50 pts",
                ageDays: 8,
                onTap: {}
            ),
            AwaitingRow(
                id: 3,
                dotColor: .earnedBar,
                title: "Problem Set 6",
                subtitle: "submitted Feb 22 · 40 pts",
                ageDays: 4,
                onTap: {}
            )
        ]
    }

    var feedbackRows: [FeedbackRow] {
        [
            FeedbackRow(
                id: 1,
                initials: "JP",
                tint: .accentHypothetical,
                author: "Prof. Pike",
                context: "Paper 1 — Ancient Empires · 48/50",
                comment: "Excellent synthesis of primary sources; watch your topic sentences.",
                onTap: {}
            ),
            FeedbackRow(
                id: 2,
                initials: "MK",
                tint: .lostMissing,
                author: "M. Keahi",
                context: "Discussion 3 · 9/10",
                comment: "Nice reply, add a citation next time.",
                onTap: {}
            ),
            FeedbackRow(
                id: 3,
                initials: "TA",
                tint: .earnedBar,
                author: "TA Nguyen",
                context: "Homework 5 · 20/20",
                comment: "Clean work all around.",
                onTap: {}
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AwaitingGradePanel(
                rows: awaitingRows,
                heldBackNote: "2 more held back by the instructor"
            )
            RecentFeedbackPanel(rows: feedbackRows)
        }
        .padding(16)
        .background(Color.canvasBG)
    }
}

#Preview("Dashboard Panels - Dark") {
    DashboardPanelsPreview()
        .preferredColorScheme(.dark)
}

#Preview("Dashboard Panels - Light") {
    DashboardPanelsPreview()
        .preferredColorScheme(.light)
}
#endif
