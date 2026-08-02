import XCTest
@testable import CanvasCore

final class PointsLedgerTests: XCTestCase {
    // One group, unweighted, 3 items @100 pts: two graded (90, 80), one ungraded.
    private func makeCalc() -> GradeCalculator {
        let items = [
            GradedItem(assignmentId: 1, name: "A", groupId: 10, pointsPossible: 100, earnedPoints: 90),
            GradedItem(assignmentId: 2, name: "B", groupId: 10, pointsPossible: 100, earnedPoints: 80),
            GradedItem(assignmentId: 3, name: "C", groupId: 10, pointsPossible: 100, earnedPoints: nil),
        ]
        return GradeCalculator(items: items, groups: [10: GroupInfo(name: "G", weight: 100)], weighted: false)
    }

    func testPointsLedgerSplits() {
        let l = makeCalc().pointsLedger()
        XCTAssertEqual(l.earned, 170, accuracy: 0.001)
        XCTAssertEqual(l.lost, 30, accuracy: 0.001)      // (100-90)+(100-80)
        XCTAssertEqual(l.inPlay, 100, accuracy: 0.001)
        XCTAssertEqual(l.total, 300, accuracy: 0.001)
        XCTAssertEqual(l.earned + l.lost + l.inPlay, l.total, accuracy: 0.001)
    }

    func testCeilingFloorBracketCurrent() {
        let calc = makeCalc()
        let now = calc.currentGrade()!        // (90+80)/200 = 85.0
        let ceiling = calc.ceilingGrade()!     // (90+80+100)/300 = 90.0
        let floor = calc.floorGrade()!         // (90+80+0)/300 = 56.666…
        XCTAssertEqual(now, 85.0, accuracy: 0.01)
        XCTAssertEqual(ceiling, 90.0, accuracy: 0.01)
        XCTAssertEqual(floor, 170.0/300.0*100, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(ceiling, now)
        XCTAssertLessThanOrEqual(floor, now)
    }

    func testMockDataLedgerIsSelfConsistent() {
        // For every demo course, earned+lost+inPlay == total and ceiling >= floor.
        for (courseId, groups) in MockData.assignmentGroups {
            let subs = MockData.submissions[courseId] ?? []
            let items = buildGradedItems(groups: groups, submissions: subs)
            let course = MockData.courses.first { $0.id == courseId }!
            let calc = GradeCalculator(items: items,
                                       groups: Dictionary(uniqueKeysWithValues: groups.map { ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight)) }),
                                       weighted: course.applyAssignmentGroupWeights ?? true)
            let l = calc.pointsLedger()
            XCTAssertEqual(l.earned + l.lost + l.inPlay, l.total, accuracy: 0.01, "course \(courseId)")
            if let c = calc.ceilingGrade(), let f = calc.floorGrade() {
                XCTAssertGreaterThanOrEqual(c + 0.001, f, "course \(courseId)")
            }
        }
    }
}
