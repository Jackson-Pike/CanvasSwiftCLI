import Foundation
import CanvasCore

@MainActor
final class AppState: ObservableObject {
    @Published var token: String? = KeychainHelper.load()
    @Published var showingSettings = false
    @Published var hasSeenIntro: Bool = UserDefaults.standard.bool(forKey: "hasSeenIntro")

    let coursesVM = CoursesViewModel()
    private var detailVMs: [Int: CourseDetailViewModel] = [:]

    var hasToken: Bool { !(token ?? "").isEmpty }

    func saveToken(_ newToken: String) {
        var trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            trimmed = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard !trimmed.isEmpty else { return }
        KeychainHelper.save(token: trimmed)
        token = trimmed
    }

    func completeIntro() {
        UserDefaults.standard.set(true, forKey: "hasSeenIntro")
        hasSeenIntro = true
    }

    func makeClient() -> APIClient? {
        guard let token, !token.isEmpty else { return nil }
        return APIClient(token: token)
    }

    func detailViewModel(for course: Course) -> CourseDetailViewModel {
        if let existing = detailVMs[course.id] { return existing }
        let vm = CourseDetailViewModel(course: course)
        detailVMs[course.id] = vm
        return vm
    }
}
