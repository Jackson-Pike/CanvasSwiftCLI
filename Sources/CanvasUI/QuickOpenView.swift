import SwiftUI
import CanvasCore

public struct SearchResultRow: View {
    public let item: SearchResultItem
    public let isSelected: Bool
    public let action: () -> Void

    public init(item: SearchResultItem, isSelected: Bool = false, action: @escaping () -> Void) {
        self.item = item
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: item.category))
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.white : Color.accentHypothetical)
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.accentHypothetical.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.inkPrimary)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.inkSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(item.category.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.inkTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.inkPrimary.opacity(0.06), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentHypothetical : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconName(for category: SearchResultItem.Category) -> String {
        switch category {
        case .course: return "book.fill"
        case .assignment: return "square.and.pencil"
        case .announcement: return "megaphone.fill"
        case .discussion: return "bubble.left.and.bubble.right.fill"
        case .file: return "doc.fill"
        case .moduleItem: return "square.stack.3d.up.fill"
        }
    }
}
