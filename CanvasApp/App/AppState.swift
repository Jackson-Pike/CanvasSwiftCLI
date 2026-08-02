import Foundation
import SwiftUI
import CanvasCore

@MainActor
final class AppState: ObservableObject {
    // Temporary hardcoded host — a later task replaces AppState with AppSession,
    // which will make the host user-configurable.
    private static let defaultHost = "byuh.instructure.com"

    @Published var token: String? = nil
    @Published var navigationPath = NavigationPath()
    @Published var hasSeenIntro: Bool = UserDefaults.standard.bool(forKey: "hasSeenIntro")
    @Published var hasAcknowledgedKeychain: Bool = UserDefaults.standard.bool(forKey: "hasAcknowledgedKeychain")

    let hiddenCoursesStore: HiddenCoursesStore
    let coursesVM: CoursesViewModel
    private var detailVMs: [Int: CourseDetailViewModel] = [:]

    init() {
        let store = HiddenCoursesStore()
        hiddenCoursesStore = store
        coursesVM = CoursesViewModel(hiddenStore: store)
        if hasAcknowledgedKeychain {
            token = KeychainHelper.load(host: Self.defaultHost)
        }
    }

    var hasToken: Bool { !(token ?? "").isEmpty }

    func saveToken(_ newToken: String) {
        var trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") {
            trimmed = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard !trimmed.isEmpty else { return }
        KeychainHelper.save(token: trimmed, host: Self.defaultHost)
        token = trimmed
    }

    func completeIntro() {
        UserDefaults.standard.set(true, forKey: "hasSeenIntro")
        hasSeenIntro = true
    }

    func acknowledgeKeychain() {
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedKeychain")
        hasAcknowledgedKeychain = true
        token = KeychainHelper.load(host: Self.defaultHost)
    }

    func makeClient() -> APIClient? {
        guard let token, !token.isEmpty else { return nil }
        return APIClient(credentials: Credentials(host: Self.defaultHost, token: token))
    }

    func detailViewModel(for course: Course) -> CourseDetailViewModel {
        if let existing = detailVMs[course.id] { return existing }
        let vm = CourseDetailViewModel(course: course)
        detailVMs[course.id] = vm
        return vm
    }
}
