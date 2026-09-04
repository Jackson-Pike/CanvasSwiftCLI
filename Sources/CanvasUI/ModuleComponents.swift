import SwiftUI
import CanvasData

public struct ModuleSectionView: View {
    public let module: CachedModule
    public let items: [CachedModuleItem]
    public let onItemSelect: (CachedModuleItem) -> Void

    /// Bound so a parent can drive Expand All / Collapse All across every section.
    @Binding public var isExpanded: Bool

    public init(module: CachedModule, items: [CachedModuleItem],
                isExpanded: Binding<Bool>, onItemSelect: @escaping (CachedModuleItem) -> Void) {
        self.module = module
        self.items = items
        self._isExpanded = isExpanded
        self.onItemSelect = onItemSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(items, id: \.id) { item in
                        ModuleItemRow(item: item) {
                            onItemSelect(item)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color.inkPrimary.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.inkPrimary.opacity(0.08), lineWidth: 1)
        )
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.inkTertiary)
                    .frame(width: 14)

                Text(module.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)

                Spacer()

                // Canvas returns a module's `state` as "completed" by default when the module
                // has no completion requirements (nothing to track = trivially done), so the
                // pill is only meaningful — and only shown, matching Canvas's own web UI — when
                // at least one item actually carries a completion requirement.
                if let state = module.state, !state.isEmpty, tracksCompletion {
                    Text(state.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(stateColor(state))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(stateColor(state).opacity(0.12), in: Capsule())
                }

                Text("\(items.count) items")
                    .font(.mono(11))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A module tracks completion only if at least one of its items has a completion
    /// requirement; otherwise Canvas's "completed" state is a meaningless default.
    private var tracksCompletion: Bool {
        items.contains { $0.completionRequirementType != nil }
    }

    private func stateColor(_ state: String) -> Color {
        switch state.lowercased() {
        case "completed": return .green
        case "started": return .orange
        case "locked": return .secondary
        default: return Color.accentHypothetical
        }
    }
}

public struct ModuleItemRow: View {
    public let item: CachedModuleItem
    public let action: () -> Void

    public init(item: CachedModuleItem, action: @escaping () -> Void) {
        self.item = item
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                completionIcon
                    .frame(width: 18)

                Image(systemName: iconName(for: item.itemType))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 18)

                Text(item.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)

                Spacer()

                Text(item.itemType)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.inkTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.inkPrimary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.leading, 14 + CGFloat(item.indent * 18))
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var completionIcon: some View {
        if item.completionRequirementCompleted == true {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.green)
        } else if item.completionRequirementType != nil {
            Image(systemName: "circle")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkTertiary)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 13))
                .foregroundStyle(.clear)
        }
    }

    private func iconName(for type: String) -> String {
        switch type.lowercased() {
        case "page": return "doc.text"
        case "assignment": return "square.and.pencil"
        case "quiz": return "questionmark.circle"
        case "file": return "doc.fill"
        case "externalurl", "external_url": return "link"
        case "discussion": return "bubble.left.and.bubble.right"
        default: return "doc"
        }
    }
}
