import Foundation

@MainActor
final class HiddenCoursesStore: ObservableObject {
    @Published private(set) var hiddenIDs: Set<Int>

    private let defaultsKey = "hiddenCourseIDs"

    init() {
        let saved = UserDefaults.standard.array(forKey: "hiddenCourseIDs") as? [Int] ?? []
        hiddenIDs = Set(saved)
    }

    func hide(_ courseId: Int) {
        hiddenIDs.insert(courseId)
        persist()
    }

    func restore(_ courseId: Int) {
        hiddenIDs.remove(courseId)
        persist()
    }

    func isHidden(_ courseId: Int) -> Bool {
        hiddenIDs.contains(courseId)
    }

    private func persist() {
        UserDefaults.standard.set(Array(hiddenIDs), forKey: defaultsKey)
    }
}
