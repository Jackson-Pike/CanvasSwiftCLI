import Foundation
import CanvasCore
import CanvasData

@MainActor
final class CourseDetailViewModel: ObservableObject {
    let courseId: Int
    @Published var inputs: CalculatorInputs?
    @Published var streamItems: [StreamItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?
    @Published var courseCode: String?

    var calculator: GradeCalculator? {
        inputs.map { GradeCalculator(items: $0.items, groups: $0.groups,
                                     weighted: $0.weighted, gradingScale: $0.scale) }
    }

    init(courseId: Int) {
        self.courseId = courseId
    }

    func load(session: AppSession, force: Bool = false) async {
        readFromStore(session)                       // instant render from disk
        guard session.hasCredentials else { return }
        isLoading = (inputs == nil)                    // skeleton only when cold
        error = nil
        error = await session.refresh(.course(courseId), force: force)
        readFromStore(session)                        // re-read after sync
        isLoading = false
    }

    private func readFromStore(_ session: AppSession) {
        inputs = (try? session.repository.calculatorInputs(courseId: courseId)) ?? nil
        streamItems = (try? session.repository.stream(courseId: courseId)) ?? []
        courseCode = (try? session.repository.course(id: courseId))?.courseCode
        lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "submissions", scopeId: "\(courseId)")
    }
}
