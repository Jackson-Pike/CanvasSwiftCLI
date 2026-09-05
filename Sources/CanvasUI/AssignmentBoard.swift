import SwiftUI
import CanvasCore

// MARK: - Token mappings

public extension Color {
    /// Due-urgency → warm design token. Red for overdue/today, gold for soon,
    /// muted ink for anything further out.
    static func dueUrgencyColor(_ urgency: DueUrgency) -> Color {
        switch urgency {
        case .overdue, .today: return .lostMissing
        case .soon:            return .byuhGold
        case .upcoming, .later, .none: return .inkTertiary
        }
    }

    /// Board column tint role → token, used for the small square in a column header.
    static func boardTintColor(_ tint: BoardTint) -> Color {
        switch tint {
        case .neutral:  return .inkTertiary
        case .muted:    return .inkQuaternary
        case .accent:   return .accentHypothetical
        case .positive: return .gradeA
        case .warning:  return .byuhGold
        case .danger:   return .lostMissing
        }
    }
}

// MARK: - Group By control

/// Segmented pill control that drives the board's column grouping. Replaces
/// `AssignmentFilterChips` on the assignments screen. Active pill is `onAccent`
/// text on an `accentHypothetical` fill; inactive pills are a bare hairline outline.
public struct AssignmentGroupByControl: View {
    @Binding private var selected: AssignmentGrouping

    public init(selected: Binding<AssignmentGrouping>) {
        self._selected = selected
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text("Group by")
                .font(.sectionLabel)
                .foregroundStyle(Color.inkTertiary)
            HStack(spacing: 6) {
                ForEach(AssignmentGrouping.allCases, id: \.rawValue) { grouping in
                    Button { selected = grouping } label: { pill(for: grouping) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func pill(for grouping: AssignmentGrouping) -> some View {
        let isActive = grouping == selected
        return Text(grouping.label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isActive ? Color.onAccent : Color.inkSecondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 11)
            .background(isActive ? Color.accentHypothetical : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isActive ? Color.clear : Color.canvasHairline, lineWidth: 1))
            .contentShape(Capsule())
    }
}

// MARK: - Due chip

/// Small tabular chip summarising when an assignment is due — "Today", "2d late",
/// "in 3d", or a short date — coloured by urgency. A graded assignment shows its
/// score instead.
public struct DueChip: View {
    private let dueAt: Date?
    private let now: Date
    private let gradedText: String?

    public init(dueAt: Date?, now: Date = Date(), gradedText: String? = nil) {
        self.dueAt = dueAt
        self.now = now
        self.gradedText = gradedText
    }

    public var body: some View {
        if let text = label {
            Text(text)
                .font(.mono(10.5, weight: .semibold))
                .foregroundStyle(color)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                .fixedSize()
        }
    }

    private var urgency: DueUrgency { dueUrgency(dueAt: dueAt, now: now) }

    private var color: Color {
        gradedText != nil ? Color.inkTertiary : Color.dueUrgencyColor(urgency)
    }

    private var label: String? {
        if let gradedText { return gradedText }
        guard let dueAt else { return nil }
        let days = calendarDaysUntil(dueAt, from: now)
        switch urgency {
        case .overdue:  return "\(abs(days))d late"
        case .today:    return "Today"
        case .soon:     return days == 1 ? "Tomorrow" : "in \(days)d"
        case .upcoming, .later: return AssignmentComponentFormat.shortDate.string(from: dueAt)
        case .none:     return nil
        }
    }
}

// MARK: - Board card

/// A single assignment on the board. Reproduces the mockup's card: raised surface,
/// hairline border, 2-line title with a due chip, a `points · kind` metadata row in
/// tabular mono, and an `accentHypothetical` ring when selected. Single-tap selects;
/// double-tap invokes `onOpen` (the full-screen page).
public struct AssignmentBoardCard: View {
    private let name: String
    private let dueAt: Date?
    private let now: Date
    private let pointsPossible: Double?
    private let kind: String
    private let gradedText: String?
    private let isSelected: Bool
    private let onTap: () -> Void
    private let onOpen: () -> Void

    @State private var isHovering = false

    public init(name: String, dueAt: Date?, now: Date = Date(), pointsPossible: Double?,
                kind: String, gradedText: String? = nil, isSelected: Bool,
                onTap: @escaping () -> Void, onOpen: @escaping () -> Void) {
        self.name = name
        self.dueAt = dueAt
        self.now = now
        self.pointsPossible = pointsPossible
        self.kind = kind
        self.gradedText = gradedText
        self.isSelected = isSelected
        self.onTap = onTap
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DueChip(dueAt: dueAt, now: now, gradedText: gradedText)
            }
            HStack(spacing: 8) {
                Text(pointsText)
                Circle().fill(Color.inkQuaternary.opacity(0.6)).frame(width: 3, height: 3)
                Text(kind)
            }
            .font(.mono(10.5))
            .foregroundStyle(Color.inkTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.canvasRaised, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(isSelected ? Color.accentHypothetical : Color.canvasHairline,
                              lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.10 : (isHovering ? 0.08 : 0.05)),
                radius: isSelected ? 4 : (isHovering ? 3 : 2), x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onTap)
        .onHover { isHovering = $0 }
    }

    private var pointsText: String {
        guard let pointsPossible else { return "—" }
        return AssignmentComponentFormat.points(pointsPossible) + " pts"
    }
}

// MARK: - Board column

/// One board column: a header (tint square, label, count, mono meta) over its content,
/// with an empty state when it holds no cards. Generic over card content so the app layer
/// supplies the `AssignmentBoardCard`s from its cached rows.
public struct AssignmentBoardColumn<Content: View>: View {
    private let label: String
    private let tint: BoardTint
    private let count: Int
    private let meta: String?
    private let content: Content

    public init(label: String, tint: BoardTint, count: Int, meta: String? = nil,
                @ViewBuilder content: () -> Content) {
        self.label = label
        self.tint = tint
        self.count = count
        self.meta = meta
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.boardTintColor(tint))
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text("\(count)")
                    .font(.mono(11))
                    .foregroundStyle(Color.inkTertiary)
                Spacer(minLength: 6)
                if let meta {
                    Text(meta)
                        .font(.mono(10.5))
                        .foregroundStyle(Color.inkQuaternary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 9)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if count == 0 {
                        Text("Nothing here yet")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.inkQuaternary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(Color.canvasHairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    } else {
                        content
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 272)
    }
}

// MARK: - Board summary line

/// The toolbar summary — "N due this week · earned/total pts · in-play on the table" —
/// built from a `PointsLedger`. Numbers are tabular mono.
public struct BoardSummaryLine: View {
    private let dueThisWeek: Int
    private let ledger: PointsLedger

    public init(dueThisWeek: Int, ledger: PointsLedger) {
        self.dueThisWeek = dueThisWeek
        self.ledger = ledger
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text("\(dueThisWeek) due this week")
            divider
            Text("\(fmt(ledger.earned))/\(fmt(ledger.total)) pts earned")
            divider
            Text("\(fmt(ledger.inPlay)) still on the table")
        }
        .font(.mono(11.5))
        .foregroundStyle(Color.inkSecondary)
        .lineLimit(1)
    }

    private var divider: some View {
        Rectangle().fill(Color.canvasHairline).frame(width: 1, height: 14)
    }

    private func fmt(_ v: Double) -> String { AssignmentComponentFormat.points(v) }
}

// MARK: - Detail pane pieces

/// The status / points / grade-weight pills beneath a selected assignment's title.
public struct DetailStatusPills: View {
    private let statusLabel: String
    private let statusTint: BoardTint
    private let pointsText: String
    private let gradeWeightText: String?

    public init(statusLabel: String, statusTint: BoardTint,
                pointsText: String, gradeWeightText: String?) {
        self.statusLabel = statusLabel
        self.statusTint = statusTint
        self.pointsText = pointsText
        self.gradeWeightText = gradeWeightText
    }

    public var body: some View {
        HStack(spacing: 7) {
            tinted(statusLabel, Color.boardTintColor(statusTint))
            neutral(pointsText)
            if let gradeWeightText { neutral(gradeWeightText) }
        }
    }

    private func tinted(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.vertical, 3).padding(.horizontal, 9)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func neutral(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Color.inkSecondary)
            .padding(.vertical, 3).padding(.horizontal, 9)
            .background(Color.inkPrimary.opacity(0.05), in: Capsule())
    }
}

/// A serif small-caps eyebrow followed by a hairline rule and optional trailing note.
public struct DetailSectionHeader: View {
    private let title: String
    private let trailing: String?

    public init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.sectionLabel)
                .foregroundStyle(Color.inkSecondary)
            Rectangle().fill(Color.canvasHairline).frame(height: 1)
            if let trailing {
                Text(trailing)
                    .font(.mono(10.5))
                    .foregroundStyle(Color.inkTertiary)
                    .fixedSize()
            }
        }
    }
}

/// "Related in this course" chips (module names). Scrolls horizontally when they overflow.
public struct RelatedModulesChips: View {
    private let modules: [String]

    public init(modules: [String]) {
        self.modules = modules
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(modules.enumerated()), id: \.offset) { _, name in
                    Text(name)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.vertical, 5).padding(.horizontal, 10)
                        .background(Color.canvasPanel, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.canvasHairline, lineWidth: 1))
                        .lineLimit(1)
                }
            }
        }
    }
}
