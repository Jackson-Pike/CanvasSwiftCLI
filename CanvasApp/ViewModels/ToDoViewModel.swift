import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

@MainActor
@Observable
final class ToDoViewModel {
    public var missingItems: [ToDoItem] = []
    public var dueThisWeekItems: [ToDoItem] = []
    public var awaitingGradeItems: [ToDoItem] = []
    public var courseColors: [Int: Color] = [:]
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    public init() {}

    public func load(session: AppSession) async {
        isLoading = true
        errorMessage = nil
        let now = Date()
        let start = now.addingTimeInterval(-14 * 86400)
        let end = now.addingTimeInterval(14 * 86400)

        do {
            try await session.syncEngine.refresh(.planner(start: start, end: end))
        } catch {
            self.errorMessage = error.localizedDescription
        }

        let repo = session.repository

        let missingPlanner = (try? repo.toDoMissing(now: now)) ?? []
        let dueWeekPlanner = (try? repo.toDoDueThisWeek(now: now)) ?? []
        let awaitingSubs = (try? repo.toDoAwaitingGrade()) ?? []

        // Course name lookups
        let courses = (try? repo.courses()) ?? []
        let courseMap = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0.name) })

        self.courseColors = Color.courseAccentMap(courseIDs: courses.map(\.id))

        self.missingItems = missingPlanner.map { item in
            let cName = item.courseId.flatMap { courseMap[$0] } ?? "Course"
            return ToDoItem(
                id: item.id,
                title: item.title,
                courseId: item.courseId,
                date: item.plannableDate,
                statusText: "Missing (\(cName))",
                isMissing: true,
                htmlUrl: item.htmlUrl
            )
        }

        self.dueThisWeekItems = dueWeekPlanner.map { item in
            let cName = item.courseId.flatMap { courseMap[$0] } ?? "Course"
            return ToDoItem(
                id: item.id,
                title: item.title,
                courseId: item.courseId,
                date: item.plannableDate,
                statusText: cName,
                htmlUrl: item.htmlUrl
            )
        }

        self.awaitingGradeItems = awaitingSubs.compactMap { sub in
            let assignment = try? repo.assignment(id: sub.assignmentId)
            let cName = courseMap[sub.courseId] ?? "Course"
            let title = assignment?.name ?? "Assignment #\(sub.assignmentId)"
            return ToDoItem(
                id: "sub_\(sub.id)",
                title: title,
                courseId: sub.courseId,
                date: sub.submittedAt,
                statusText: "Submitted — awaiting grade (\(cName))",
                isAwaitingGrade: true,
                htmlUrl: assignment?.htmlURL
            )
        }

        if !missingItems.isEmpty || !dueThisWeekItems.isEmpty || !awaitingGradeItems.isEmpty {
            self.errorMessage = nil
        }
        isLoading = false
    }
}
