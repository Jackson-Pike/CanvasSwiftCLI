import SwiftUI

// MARK: - AnnouncementListRow

/// One announcement in the announcements-tab list. Same grammar as
/// `AssignmentListRow`: 1px `canvasRule` divider on top, `inkPrimary`@4% fill
/// when selected. Unread rows carry a 6pt filled `inkPrimary` dot to the left
/// of the title; read rows reserve the same gutter so titles stay aligned.
public struct AnnouncementListRow: View {
    private let title: String
    private let authorName: String?
    private let postedAt: Date?
    private let isUnread: Bool
    private let isSelected: Bool
    private let onTap: () -> Void

    @State private var isHovering = false

    public init(
        title: String,
        authorName: String?,
        postedAt: Date?,
        isUnread: Bool,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.authorName = authorName
        self.postedAt = postedAt
        self.isUnread = isUnread
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

            HStack(alignment: .top, spacing: 8) {
                // Fixed-width gutter keeps read and unread titles on the same axis.
                Group {
                    if isUnread {
                        Circle()
                            .fill(Color.inkPrimary)
                            .frame(width: 6, height: 6)
                    } else {
                        Color.clear
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: 6, alignment: .center)
                .padding(.top, 5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: isUnread ? .semibold : .regular))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.inkTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
        }
        .background(isSelected ? Color.inkPrimary.opacity(0.04) : Color.clear)
        .background(isHovering && !isSelected ? Color.inkPrimary.opacity(0.02) : Color.clear)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if let authorName, !authorName.isEmpty {
            parts.append(authorName)
        }
        if let postedAt {
            parts.append(AnnouncementComponentFormat.shortDate.string(from: postedAt))
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

// MARK: - Formatting helpers

enum AnnouncementComponentFormat {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

// MARK: - Previews

#if DEBUG
private struct AnnouncementComponentsPreview: View {
    private var posted: Date { Date(timeIntervalSince1970: 1_772_000_000) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "megaphone")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.inkTertiary)
                Text("Announcements")
                    .font(.sectionLabel)
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.bottom, 6)

            AnnouncementListRow(
                title: "Midterm review session moved to Thursday",
                authorName: "Prof. Pike",
                postedAt: posted,
                isUnread: true,
                isSelected: false,
                onTap: {}
            )
            AnnouncementListRow(
                title: "Lab 4 rubric posted — read before you submit",
                authorName: "TA Nguyen",
                postedAt: posted,
                isUnread: true,
                isSelected: true,
                onTap: {}
            )
            AnnouncementListRow(
                title: "Welcome to the course",
                authorName: "Prof. Pike",
                postedAt: posted,
                isUnread: false,
                isSelected: false,
                onTap: {}
            )
            AnnouncementListRow(
                title: "Office hours this week",
                authorName: nil,
                postedAt: nil,
                isUnread: false,
                isSelected: false,
                onTap: {}
            )
        }
        .padding(16)
        .frame(width: 420)
        .background(Color.canvasBG)
    }
}

#Preview("Announcement Components - Light") {
    AnnouncementComponentsPreview()
        .preferredColorScheme(.light)
}

#Preview("Announcement Components - Dark") {
    AnnouncementComponentsPreview()
        .preferredColorScheme(.dark)
}
#endif
