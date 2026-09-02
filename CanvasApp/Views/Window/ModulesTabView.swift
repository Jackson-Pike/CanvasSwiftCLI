import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct ModulesTabView: View {
    let courseId: Int
    @StateObject private var vm = ModulesViewModel()
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router

    var body: some View {
        Group {
            if vm.isLoading && vm.modules.isEmpty {
                SkeletonList()
            } else if vm.modules.isEmpty {
                ContentUnavailableView("No Modules Available", systemImage: "square.stack.3d.up", description: Text("This course does not have any published modules."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(vm.modules, id: \.id) { module in
                            ModuleSectionView(
                                module: module,
                                items: vm.moduleItems[module.id] ?? []
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
}
