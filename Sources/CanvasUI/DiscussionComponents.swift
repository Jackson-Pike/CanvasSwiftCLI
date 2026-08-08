import SwiftUI
import CanvasCore

public struct DiscussionTopicRow: View {
    let title: String
    let replyCount: Int
    let postedAt: Date?
    let isSelected: Bool
    let onTap: () -> Void

    public init(title: String, replyCount: Int, postedAt: Date?, isSelected: Bool, onTap: @escaping () -> Void) {
        self.title = title; self.replyCount = replyCount; self.postedAt = postedAt
        self.isSelected = isSelected; self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.inkPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Label("\(replyCount)", systemImage: "bubble.left")
                        .font(.system(size: 10)).foregroundStyle(Color.inkTertiary)
                    if let postedAt {
                        Text(postedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10)).foregroundStyle(Color.inkTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSelected ? Color.inkPrimary.opacity(0.06) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

public struct DiscussionEntryView: View {
    let authorName: String
    let message: String
    let date: Date?
    let depth: Int

    public init(authorName: String, message: String, date: Date?, depth: Int) {
        self.authorName = authorName; self.message = message; self.date = date; self.depth = depth
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(authorName).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.inkSecondary)
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9)).foregroundStyle(Color.inkTertiary)
                }
            }
            RichTextView(html: message)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, CGFloat(depth) * 20)   // indent by depth (spec §5.3)
        .overlay(alignment: .leading) {
            if depth > 0 {
                Rectangle().fill(Color.canvasHairline).frame(width: 1)
                    .padding(.leading, CGFloat(depth) * 20 - 10)
            }
        }
    }
}
