import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct ModulesTabView: View {
    let courseId: Int
    @StateObject private var vm = ModulesViewModel()
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    /// Module IDs currently collapsed. Empty = all expanded (the default), so newly synced
    /// modules start open without needing to seed this set.
    @State private var collapsed: Set<Int> = []

    /// At least one module is open → the useful action is "Collapse All"; otherwise "Expand All".
    private var anyExpanded: Bool { collapsed.count < vm.modules.count }

    var body: some View {
        Group {
            if vm.isLoading && vm.modules.isEmpty {
                SkeletonList()
            } else if vm.modules.isEmpty {
                ContentUnavailableView("No Modules Available", systemImage: "square.stack.3d.up", description: Text("This course does not have any published modules."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        expandCollapseBar
                        ForEach(vm.modules, id: \.id) { module in
                            ModuleSectionView(
                                module: module,
                                items: vm.moduleItems[module.id] ?? [],
                                isExpanded: binding(for: module.id)
                            ) { item in
                                vm.handleItemSelect(item, router: router)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .task(id: courseId) {
            await vm.load(session: session, courseId: courseId)
        }
    }

    private var expandCollapseBar: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    collapsed = anyExpanded ? Set(vm.modules.map(\.id)) : []
                }
            } label: {
                Label(anyExpanded ? "Collapse All" : "Expand All",
                      systemImage: anyExpanded ? "chevron.up.chevron.down" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentHypothetical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(anyExpanded ? "Collapse all modules" : "Expand all modules")
        }
    }

    private func binding(for moduleId: Int) -> Binding<Bool> {
        Binding(
            get: { !collapsed.contains(moduleId) },
            set: { isExpanded in
                if isExpanded { collapsed.remove(moduleId) } else { collapsed.insert(moduleId) }
            }
        )
    }
}
