import SwiftUI
import CanvasCore
import CanvasData

@MainActor
final class ModulesViewModel: ObservableObject {
    @Published var modules: [CachedModule] = []
    @Published var moduleItems: [Int: [CachedModuleItem]] = [:]
    @Published var isLoading = false
    @Published var error: String?

    func load(session: AppSession, courseId: Int) async {
        isLoading = true
        fetchLocal(session: session, courseId: courseId)
        do {
            try await session.syncEngine.refresh(.modules(courseId: courseId))
            fetchLocal(session: session, courseId: courseId)
            error = nil
        } catch {
            self.error = String(describing: error)
        }
        isLoading = false
    }

    private func fetchLocal(session: AppSession, courseId: Int) {
        do {
            let mods = try session.repository.modules(courseId: courseId)
            self.modules = mods
            var itemsMap: [Int: [CachedModuleItem]] = [:]
            for m in mods {
                itemsMap[m.id] = (try? session.repository.moduleItems(moduleId: m.id)) ?? []
            }
            self.moduleItems = itemsMap
        } catch {
            self.error = error.localizedDescription
        }
    }

    func handleItemSelect(_ item: CachedModuleItem, router: Router) {
        if item.itemType == "Assignment", let contentId = item.contentId {
            router.reveal(.assignment(courseId: item.courseId, assignmentId: contentId))
        } else if let extUrl = item.externalUrl, let url = URL(string: extUrl) {
            NSWorkspace.shared.open(url)
        } else if let htmlUrl = item.htmlURL, let url = URL(string: htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
