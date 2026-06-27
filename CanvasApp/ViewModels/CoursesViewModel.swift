import Foundation
import Combine
import CanvasCore

@MainActor
final class CoursesViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var enrollments: [Int: Enrollment] = [:]
    @Published var isLoading = false
    @Published var error: String?

    @Published private(set) var allFetchedCourses: [Course] = []
    private let hiddenStore: HiddenCoursesStore
    private var cancellable: AnyCancellable?

    private var lastFetchedAt: Date?
    private let cacheTTL: TimeInterval = 5 * 60
    private var fetchTask: Task<Void, Never>?

    init(hiddenStore: HiddenCoursesStore) {
        self.hiddenStore = hiddenStore
        cancellable = hiddenStore.$hiddenIDs.sink { [weak self] _ in
            self?.applyFilter()
        }
    }

    private func applyFilter() {
        courses = allFetchedCourses.filter { !hiddenStore.isHidden($0.id) }
    }

    func fetch(client: APIClient, force: Bool = false) {
        fetchTask?.cancel()
        fetchTask = Task {
            await _fetch(client: client, force: force)
        }
    }

    private func _fetch(client: APIClient, force: Bool) async {
        if !force,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < cacheTTL,
           !allFetchedCourses.isEmpty {
            return
        }
        isLoading = true
        error = nil
        do {
            let fetched = try await client.courses()
            guard !Task.isCancelled else { isLoading = false; return }
            allFetchedCourses = fetched
            applyFilter()
            await withTaskGroup(of: (Int, Enrollment?).self) { group in
                for course in fetched {
                    group.addTask {
                        let e = try? await client.enrollments(courseId: course.id).first
                        return (course.id, e)
                    }
                }
                for await (id, enrollment) in group {
                    if let enrollment { self.enrollments[id] = enrollment }
                }
            }
            lastFetchedAt = Date()
        } catch let e as APIError {
            error = e.description
        } catch let e as DecodingError {
            switch e {
            case .keyNotFound(let key, let ctx):
                self.error = "Missing field '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
            case .typeMismatch(let type, let ctx):
                self.error = "Type mismatch (\(type)) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
            case .valueNotFound(let type, let ctx):
                self.error = "Null value (\(type)) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
            case .dataCorrupted(let ctx):
                self.error = "Corrupted data at \(ctx.codingPath.map(\.stringValue).joined(separator: ".")): \(ctx.debugDescription)"
            @unknown default:
                self.error = e.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func currentScore(for courseId: Int) -> Double? {
        enrollments[courseId]?.grades?.currentScore
    }
}
