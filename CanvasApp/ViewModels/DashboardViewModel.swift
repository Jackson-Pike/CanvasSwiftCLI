import Foundation
import SwiftUI
import CanvasCore
import CanvasData

/// One row of the dashboard's cross-course ledger table.
struct CourseLedgerRow: Identifiable {
    let id: Int                    // courseId
    let code: String
    let name: String
    let dotColor: Color
    let nowPercent: Double?
    let ledger: PointsLedger
    let ceilingPercent: Double?
    let ceilingLetter: String?
    let floorPercent: Double?
    let floorLetter: String?
    let missingCount: Int
    let missingLabel: String?
}

/// Aggregates every non-hidden course into a single term view: GPA (now/ceiling/floor),
/// total points still in play, a per-course ledger, and a merged activity stream
/// (awaiting-grade + recent feedback) across all courses.
@MainActor @Observable
final class DashboardViewModel {
    var termGPA: Double?
    var ceilingGPA: Double?
    var floorGPA: Double?
    var pointsInPlay: Double = 0
    var rows: [CourseLedgerRow] = []
    private(set) var summaries: [CourseGradeSummary] = []
    var awaitingGrade: [StreamItem] = []
    var recentFeedback: [StreamItem] = []
    var termStart: Date?
    var termEnd: Date?
    var isLoading = false
    var error: String?
    var lastSyncedAt: Date?

    func load(session: AppSession, coursesVM: CoursesViewModel, settings: CourseSettingsStore, force: Bool = false) async {
        readFromStore(session: session, coursesVM: coursesVM, settings: settings)   // instant render from disk
        guard session.hasCredentials else { return }
        isLoading = rows.isEmpty                        // skeleton only when cold
        error = nil
        error = await session.refresh(.all, force: force)
        readFromStore(session: session, coursesVM: coursesVM, settings: settings)   // re-read after sync
        isLoading = false
    }

    private func readFromStore(session: AppSession, coursesVM: CoursesViewModel, settings: CourseSettingsStore) {
        let repository = session.repository
        let visibleCourses = coursesVM.courses.filter { !$0.hidden }

        var newRows: [CourseLedgerRow] = []
        var summaries: [CourseGradeSummary] = []
        var allAwaitingGrade: [StreamItem] = []
        var allFeedback: [StreamItem] = []
        var allDueDates: [Date] = []
        let now = Date()

        for course in visibleCourses {
            guard let inputs = (try? repository.calculatorInputs(courseId: course.id)) ?? nil else { continue }
            let calc = GradeCalculator(items: inputs.items, groups: inputs.groups,
                                       weighted: inputs.weighted, gradingScale: inputs.scale)
            let nowPercent = calc.currentGrade()
            let ledger = calc.pointsLedger()
            let ceilingPercent = calc.ceilingGrade()
            let floorPercent = calc.floorGrade()

            let streamItems = (try? repository.stream(courseId: course.id, now: now)) ?? []
            let courseAwaitingGrade = streamItems.filter {
                if case .awaitingGrade = $0.kind { return true }
                return false
            }
            let missingCount = courseAwaitingGrade.filter {
                if let due = $0.assignment.dueAt { return due < now }
                return false
            }.count

            newRows.append(CourseLedgerRow(
                id: course.id,
                code: course.courseCode,
                name: course.name,
                dotColor: Self.dotColor(for: course.courseCode),
                nowPercent: nowPercent,
                ledger: ledger,
                ceilingPercent: ceilingPercent,
                ceilingLetter: ceilingPercent.map { calc.letterGradeForPercent($0) },
                floorPercent: floorPercent,
                floorLetter: floorPercent.map { calc.letterGradeForPercent($0) },
                missingCount: missingCount,
                missingLabel: missingCount > 0 ? "\(missingCount) missing" : nil
            ))

            summaries.append(CourseGradeSummary(
                courseId: course.id,
                credits: settings.credits(for: course.id),
                nowPercent: nowPercent,
                ceilingPercent: ceilingPercent,
                floorPercent: floorPercent,
                scale: course.gradingScale
            ))

            allAwaitingGrade.append(contentsOf: courseAwaitingGrade)
            allFeedback.append(contentsOf: streamItems.filter {
                if case .feedback = $0.kind { return true }
                return false
            })
            allDueDates.append(contentsOf: streamItems.compactMap { $0.assignment.dueAt })
        }

        rows = newRows
        self.summaries = summaries
        termGPA = currentTermGPA(summaries)
        ceilingGPA = ceilingTermGPA(summaries)
        floorGPA = floorTermGPA(summaries)
        pointsInPlay = newRows.reduce(0) { $0 + $1.ledger.inPlay }

        awaitingGrade = allAwaitingGrade.sorted {
            ($0.assignment.dueAt ?? .distantPast) > ($1.assignment.dueAt ?? .distantPast)
        }
        recentFeedback = allFeedback
            .sorted { lhs, rhs in
                guard case .feedback(_, _, let lDate) = lhs.kind,
                      case .feedback(_, _, let rDate) = rhs.kind else { return false }
                return (lDate ?? .distantPast) > (rDate ?? .distantPast)
            }
            .prefix(3)
            .map { $0 }

        termStart = allDueDates.min()
        termEnd = allDueDates.max()
        lastSyncedAt = try? repository.lastSyncedAt(entityKind: "courses", scopeId: "all")
    }

    /// Fixed demo palette by course-code prefix; falls back to a stable hash color for
    /// anything outside the demo set (mirrors `MainWindowView.accentColor(for:)`).
    private static func dotColor(for code: String) -> Color {
        let upper = code.uppercased()
        if upper.hasPrefix("CS")   { return Color(red: 0x14 / 255, green: 0xB8 / 255, blue: 0xA6 / 255) }
        if upper.hasPrefix("MATH") { return Color(red: 0x3B / 255, green: 0x82 / 255, blue: 0xF6 / 255) }
        if upper.hasPrefix("HIST") { return Color(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255) }
        if upper.hasPrefix("REL")  { return Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255) }
        let hues: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .red]
        return hues[abs(code.hashValue) % hues.count]
    }
}
