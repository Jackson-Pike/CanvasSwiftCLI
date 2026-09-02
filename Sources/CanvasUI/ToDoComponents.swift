import SwiftUI
import CanvasCore

public struct ToDoItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let courseId: Int?
    public let date: Date?
    public let statusText: String
    public let isMissing: Bool
    public let isAwaitingGrade: Bool
    public let htmlUrl: String?

    public init(
        id: String,
        title: String,
        courseId: Int?,
        date: Date?,
        statusText: String,
        isMissing: Bool = false,
        isAwaitingGrade: Bool = false,
        htmlUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.courseId = courseId
        self.date = date
        self.statusText = statusText
        self.isMissing = isMissing
        self.isAwaitingGrade = isAwaitingGrade
        self.htmlUrl = htmlUrl
    }
}

public struct ToDoSectionHeader: View {
    public let title: String
    public let iconName: String
    public let iconColor: Color
    public let count: Int

    public init(title: String, iconName: String, iconColor: Color, count: Int) {
        self.title = title
        self.iconName = iconName
        self.iconColor = iconColor
        self.count = count
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)

            Text(title)
                .font(.headline)
                .foregroundColor(.inkPrimary)

            Text("\(count)")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(iconColor.opacity(0.15))
                .foregroundColor(iconColor)
                .cornerRadius(10)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

public struct ToDoItemRow: View {
    public let item: ToDoItem
    public let courseColor: Color
    public let onItemClick: ((ToDoItem) -> Void)?

    public init(
        item: ToDoItem,
        courseColor: Color = Color.accentHypothetical,
        onItemClick: ((ToDoItem) -> Void)? = nil
    ) {
        self.item = item
        self.courseColor = courseColor
        self.onItemClick = onItemClick
    }

    public var body: some View {
        Button {
            onItemClick?(item)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(courseColor)
                    .frame(width: 4, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.inkPrimary)

                    HStack(spacing: 8) {
                        Text(item.statusText)
                            .font(.caption)
                            .foregroundColor(item.isMissing ? .lostMissing : .inkSecondary)

                        if let date = item.date {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.inkTertiary)
                            Text(date.formatted(.dateTime.month().day().hour().minute()))
                                .font(.caption)
                                .foregroundColor(.inkTertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.inkTertiary)
            }
            .padding(10)
            .hairlineRow()
        }
        .buttonStyle(.plain)
    }
}

public struct DueSoonStrip: View {
    public let items: [ToDoItem]
    public let courseColors: [Int: Color]
    public let onItemClick: ((ToDoItem) -> Void)?

    public init(
        items: [ToDoItem],
        courseColors: [Int: Color] = [:],
        onItemClick: ((ToDoItem) -> Void)? = nil
    ) {
        self.items = items
        self.courseColors = courseColors
        self.onItemClick = onItemClick
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(.orange)
                    Text("Due Soon (Next 24 Hours)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.inkPrimary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            let color = item.courseId.flatMap { courseColors[$0] } ?? .orange
                            Button {
                                onItemClick?(item)
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(1)
                                            .foregroundColor(.inkPrimary)
                                        if let date = item.date {
                                            Text(date, style: .time)
                                                .font(.caption2)
                                                .foregroundColor(.inkSecondary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.canvasPanel)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(color.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(10)
        }
    }
}
