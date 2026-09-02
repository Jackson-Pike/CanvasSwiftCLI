import SwiftUI
import CanvasCore
import CanvasData

@MainActor
final class QuickOpenViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            selectedIndex = 0
        }
    }
    @Published var results: [SearchResultItem] = []
    @Published var selectedIndex: Int = 0

    func performSearch(session: AppSession) {
        do {
            results = try session.repository.search(query: query)
            if selectedIndex >= results.count {
                selectedIndex = max(0, results.count - 1)
            }
        } catch {
            results = []
        }
    }

    func moveSelection(up: Bool) {
        guard !results.isEmpty else { return }
        if up {
            selectedIndex = max(0, selectedIndex - 1)
        } else {
            selectedIndex = min(results.count - 1, selectedIndex + 1)
        }
    }

    func selectCurrent(router: Router) {
        guard selectedIndex >= 0 && selectedIndex < results.count else { return }
        if let target = results[selectedIndex].target {
            router.revealSearchTarget(target)
        }
    }
}
