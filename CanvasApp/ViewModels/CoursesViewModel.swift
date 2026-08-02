import Foundation
import CanvasCore
import CanvasData

@MainActor
final class CoursesViewModel: ObservableObject {
    @Published var courses: [CachedCourse] = []
    @Published var isLoading = false          // true only while syncing with an empty cache
    @Published var error: String?
    @Published var lastSyncedAt: Date?
    @Published var unseenChanges: [ChangeRecord] = []

    private var scores: [Int: Double] = [:]

    init() {}

    func load(session: AppSession, force: Bool = false) async {
        readFromStore(session)                       // instant render from disk
        guard session.hasCredentials else { return }
        isLoading = courses.isEmpty                   // skeleton only when cold
        error = nil
        error = await session.refresh(.all, force: force)
        readFromStore(session)                        // re-read after sync
        isLoading = false
    }

    private func readFromStore(_ session: AppSession) {
        courses = (try? session.repository.courses()) ?? []
        var newScores: [Int: Double] = [:]
        for course in courses {
            if let enrollment = try? session.repository.enrollment(courseId: course.id),
               let score = enrollment.currentScore {
                newScores[course.id] = score
            }
        }
        scores = newScores
        lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "courses", scopeId: "all")
        unseenChanges = (try? session.repository.unseenChanges()) ?? []
    }

    func currentScore(for courseId: Int) -> Double? {
        scores[courseId]
    }

    func letter(for courseId: Int) -> String? {
        guard let score = scores[courseId],
              let course = courses.first(where: { $0.id == courseId }) else { return nil }
        return letterGrade(for: score, scale: course.gradingScale)
    }

    func hide(courseId: Int, session: AppSession) {
        try? session.repository.setHidden(true, courseId: courseId)
        readFromStore(session)
    }

    func restore(courseId: Int, session: AppSession) {
        try? session.repository.setHidden(false, courseId: courseId)
        readFromStore(session)
    }

    func hiddenCourses(session: AppSession) -> [CachedCourse] {
        ((try? session.repository.courses(includeHidden: true)) ?? []).filter(\.hidden)
    }

    func markChangesSeen(session: AppSession) {
        try? session.repository.markChangesSeen()
        unseenChanges = (try? session.repository.unseenChanges()) ?? []
    }
}
