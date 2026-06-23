import XCTest
@testable import CanvasCLISwift

final class GradeCalculatorTests: XCTestCase {
    private func item(_ id: Int, group: Int, possible: Double, earned: Double?) -> GradedItem {
        GradedItem(assignmentId: id, name: "A\(id)", groupId: group, pointsPossible: possible, earnedPoints: earned, whatIfPoints: nil)
    }

    func testBuildGradedItemsJoinsScores() {
        let groups = [AssignmentGroup(id: 1, name: "HW", groupWeight: 100,
            assignments: [Assignment(id: 100, name: "HW1", pointsPossible: 10, dueAt: nil, assignmentGroupId: 1)])]
        let subs = [Submission(assignmentId: 100, score: 8, workflowState: "graded")]
        let items = buildGradedItems(groups: groups, submissions: subs)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].earnedPoints, 8)
        XCTAssertEqual(items[0].groupId, 1)
    }

    func testUnweightedIgnoresUngradedItems() {
        let items = [item(1, group: 1, possible: 10, earned: 9),
                     item(2, group: 1, possible: 10, earned: nil)]
        let calc = GradeCalculator(items: items, groups: [1: GroupInfo(name: "HW", weight: 100)], weighted: false)
        XCTAssertEqual(calc.currentGrade()!, 90.0, accuracy: 0.001)
    }

    func testCurrentGradeNilWhenNothingGraded() {
        let items = [item(1, group: 1, possible: 10, earned: nil)]
        let calc = GradeCalculator(items: items, groups: [1: GroupInfo(name: "HW", weight: 100)], weighted: false)
        XCTAssertNil(calc.currentGrade())
    }
}
