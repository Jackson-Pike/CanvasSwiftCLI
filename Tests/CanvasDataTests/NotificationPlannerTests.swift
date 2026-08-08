import XCTest
import CanvasCore
@testable import CanvasData

final class NotificationPlannerTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func at(_ hour: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: hour))! }

    private func settings(_ overrides: (inout NotificationSettings) -> Void = { _ in }) -> NotificationSettings {
        var s = NotificationSettings.defaults; overrides(&s); return s
    }
    private func record(_ kind: ChangeKind, courseId: Int = 1, title: String = "T") -> ChangeRecord {
        ChangeRecord(kind: kind, courseId: courseId, subjectId: nil, title: title, detail: nil, occurredAt: Date())
    }

    func testDisabledCategoryIsDropped() {
        let s = settings { $0.newGrades = false }
        let result = NotificationPlanner.plan(changes: [record(.newGrade)], settings: s, now: at(12), calendar: cal)
        XCTAssertTrue(result.post.isEmpty)
        XCTAssertTrue(result.suppressed.isEmpty)   // disabled ≠ suppressed; it never planned
    }

    func testEnabledCategoryPosts() {
        let result = NotificationPlanner.plan(changes: [record(.newGrade, title: "Lab 3")],
                                              settings: settings(), now: at(12), calendar: cal)
        XCTAssertEqual(result.post.count, 1)
        XCTAssertTrue(result.post.first!.body.contains("Lab 3") || result.post.first!.title.contains("Lab 3"))
    }

    func testCoalescesMoreThanThreeSameKindSameCourse() {
        let changes = (0..<4).map { record(.newGrade, courseId: 1, title: "A\($0)") }
        let result = NotificationPlanner.plan(changes: changes, settings: settings(), now: at(12), calendar: cal)
        XCTAssertEqual(result.post.count, 1)                       // one summary
        XCTAssertTrue(result.post.first!.body.contains("4"))       // "4 new grades…"
    }

    func testThreeOrFewerAreIndividual() {
        let changes = (0..<3).map { record(.newGrade, courseId: 1, title: "A\($0)") }
        let result = NotificationPlanner.plan(changes: changes, settings: settings(), now: at(12), calendar: cal)
        XCTAssertEqual(result.post.count, 3)
    }

    func testQuietHoursSuppressButKeepInFeed() {
        let s = settings { $0.quietHoursEnabled = true; $0.quietStartHour = 22; $0.quietEndHour = 7 }
        let result = NotificationPlanner.plan(changes: [record(.newGrade)], settings: s, now: at(23), calendar: cal)
        XCTAssertTrue(result.post.isEmpty)
        XCTAssertEqual(result.suppressed.count, 1)   // still surfaced in change feed by caller
    }

    func testQuietHoursWrapAround() {
        let s = settings { $0.quietHoursEnabled = true; $0.quietStartHour = 22; $0.quietEndHour = 7 }
        XCTAssertTrue(NotificationPlanner.isInQuietHours(at(2), settings: s, calendar: cal))   // 02:00 inside 22→7
        XCTAssertFalse(NotificationPlanner.isInQuietHours(at(12), settings: s, calendar: cal)) // noon outside
    }
}
