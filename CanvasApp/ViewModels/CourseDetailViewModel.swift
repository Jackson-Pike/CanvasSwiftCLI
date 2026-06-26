import Foundation
import CanvasCore

@MainActor
final class CourseDetailViewModel: ObservableObject {
    let course: Course
    @Published var calculator: GradeCalculator?
    @Published var groupInfo: [Int: GroupInfo] = [:]
    @Published var allItems: [GradedItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private var lastFetchedAt: Date?
    private let cacheTTL: TimeInterval = 5 * 60

    init(course: Course) { self.course = course }

    var gradingScale: [(String, Double)] { course.gradingScale }

    func fetch(client: APIClient, force: Bool = false) async {
        if !force,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < cacheTTL,
           calculator != nil {
            return
        }
        isLoading = true
        error = nil
        do {
            async let groups = client.assignmentGroups(courseId: course.id)
            async let subs   = client.submissions(courseId: course.id)
            let (fetchedGroups, fetchedSubs) = try await (groups, subs)

            let info = Dictionary(uniqueKeysWithValues: fetchedGroups.map { g in
                (g.id, GroupInfo(name: g.name, weight: g.groupWeight,
                                 dropLowest:  g.rules?.dropLowest  ?? 0,
                                 dropHighest: g.rules?.dropHighest ?? 0,
                                 neverDrop:   Set(g.rules?.neverDrop ?? [])))
            })
            groupInfo = info
            let items = buildGradedItems(groups: fetchedGroups, submissions: fetchedSubs)
            allItems  = items
            calculator = GradeCalculator(items: items, groups: info,
                                          weighted: course.applyAssignmentGroupWeights ?? false,
                                          gradingScale: gradingScale)
            lastFetchedAt = Date()
        } catch let e as APIError { error = e.description }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}
