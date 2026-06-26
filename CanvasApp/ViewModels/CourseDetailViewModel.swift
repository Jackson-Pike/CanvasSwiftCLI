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

    init(course: Course) { self.course = course }

    var gradingScale: [(String, Double)] {
        course.gradingScale
    }

    func fetch(client: APIClient) async {
        isLoading = true; error = nil
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
                                          weighted: course.applyAssignmentGroupWeights,
                                          gradingScale: gradingScale)
        } catch let e as APIError { error = e.description }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}
