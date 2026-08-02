import SwiftUI
import CanvasData

/// Value-driven replacement for the old `CourseStreamView`.
public struct StreamSection: View {
    private let items: [StreamItem]

    public init(items: [StreamItem]) {
        self.items = items
    }

    private var awaitingGrade: [StreamItem] {
        items.filter { if case .awaitingGrade = $0.kind { return true }; return false }
    }
    private var upcoming: [StreamItem] {
        items.filter { if case .upcoming = $0.kind { return true }; return false }
    }
    private var recentlyGraded: [StreamItem] {
        items.filter { if case .recentlyGraded = $0.kind { return true }; return false }
    }
    private var recentFeedback: [StreamItem] {
        items.filter { if case .feedback = $0.kind { return true }; return false }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.top, 8)
            Text("Course Stream")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if !awaitingGrade.isEmpty {
                StreamSectionHeader(title: "Awaiting Grade", icon: "clock")
                ForEach(awaitingGrade, id: \.assignment.id) { item in
                    StreamRow(item: item)
                }
            }
            if !upcoming.isEmpty {
                StreamSectionHeader(title: "Upcoming", icon: "calendar")
                ForEach(upcoming, id: \.assignment.id) { item in
                    StreamRow(item: item)
                }
            }
            if !recentlyGraded.isEmpty {
                StreamSectionHeader(title: "Recently Graded", icon: "checkmark.circle")
                ForEach(recentlyGraded, id: \.assignment.id) { item in
                    StreamRow(item: item)
                }
            }
            if !recentFeedback.isEmpty {
                StreamSectionHeader(title: "Recent Feedback", icon: "bubble.left")
                ForEach(Array(recentFeedback.enumerated()), id: \.offset) { _, item in
                    StreamRow(item: item)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

struct StreamSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

/// Value-driven replacement for the old `StreamRowView`.
public struct StreamRow: View {
    private let item: StreamItem

    public init(item: StreamItem) {
        self.item = item
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    public var body: some View {
        switch item.kind {
        case .feedback(let authorName, let comment, let createdAt):
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.assignment.name)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let date = createdAt {
                        Text(Self.dateFormatter.string(from: date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                Text("\(authorName): \(comment)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

        default:
            HStack(spacing: 6) {
                Text(item.assignment.name)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                inlineDetail
            }
            .padding(.horizontal)
            .padding(.vertical, 3)
        }
    }

    @ViewBuilder
    private var inlineDetail: some View {
        switch item.kind {
        case .awaitingGrade:
            Text("pending")
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.orange.opacity(0.12), in: Capsule())

        case .upcoming(let due):
            Text(Self.dateFormatter.string(from: due))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

        case .recentlyGraded(let score, let possible, _):
            if let score, let possible, possible > 0 {
                Text(String(format: "%.0f / %.0f", score, possible))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("graded")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .feedback:
            EmptyView()
        }
    }
}

#Preview {
    let dueSoon = Date().addingTimeInterval(86400 * 3)
    let items = [
        StreamItem(
            assignment: StreamAssignment(id: 1, name: "Essay 1", pointsPossible: 100, dueAt: nil),
            kind: .awaitingGrade
        ),
        StreamItem(
            assignment: StreamAssignment(id: 2, name: "Homework 3", pointsPossible: 50, dueAt: dueSoon),
            kind: .upcoming(due: dueSoon)
        ),
        StreamItem(
            assignment: StreamAssignment(id: 3, name: "Quiz 2", pointsPossible: 20, dueAt: nil),
            kind: .recentlyGraded(score: 18, possible: 20, gradedAt: Date())
        ),
        StreamItem(
            assignment: StreamAssignment(id: 4, name: "Project", pointsPossible: 100, dueAt: nil),
            kind: .feedback(authorName: "Prof. Smith", comment: "Great work overall!", createdAt: Date())
        )
    ]
    return StreamSection(items: items)
}
