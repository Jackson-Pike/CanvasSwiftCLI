import XCTest
@testable import CanvasCLISwift

final class GradeCalculatorTests: XCTestCase {
    private func item(_ id: Int, group: Int, possible: Double, earned: Double?) -> GradedItem {
        GradedItem(assignmentId: id, name: "A\(id)", groupId: group, pointsPossible: possible, earnedPoints: earned, whatIfPoints: nil)
    }

    func testBuildGradedItemsJoinsScores() {
        let groups = [AssignmentGroup(id: 1, name: "HW", groupWeight: 100, rules: nil,
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

    func testWeightedGradeNormalizesOverActiveGroups() {
        // HW (weight 40): 90%. Quiz (weight 20): 80%. Final (weight 40): ungraded.
        let items = [item(1, group: 1, possible: 100, earned: 90),
                     item(2, group: 2, possible: 100, earned: 80),
                     item(3, group: 3, possible: 100, earned: nil)]
        let groups: [Int: GroupInfo] = [
            1: GroupInfo(name: "HW", weight: 40),
            2: GroupInfo(name: "Quiz", weight: 20),
            3: GroupInfo(name: "Final", weight: 40)
        ]
        let calc = GradeCalculator(items: items, groups: groups, weighted: true)
        // (0.9*40 + 0.8*20) / (40+20) = (36+16)/60 = 86.666...
        XCTAssertEqual(calc.currentGrade()!, 86.6667, accuracy: 0.001)
    }

    func testGroupBreakdownReportsNilForUngradedGroup() {
        let items = [item(1, group: 1, possible: 100, earned: 90),
                     item(3, group: 3, possible: 100, earned: nil)]
        let groups: [Int: GroupInfo] = [
            1: GroupInfo(name: "HW", weight: 60),
            3: GroupInfo(name: "Final", weight: 40)
        ]
        let calc = GradeCalculator(items: items, groups: groups, weighted: true)
        let breakdown = calc.groupBreakdown().sorted { $0.groupId < $1.groupId }
        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown[0].percent!, 90.0, accuracy: 0.001)
        XCTAssertNil(breakdown[1].percent)
    }

    func testApplyingWhatIfSetsSelectedItemsByPercent() {
        let items = [item(1, group: 1, possible: 50, earned: 25),
                     item(2, group: 1, possible: 50, earned: 50)]
        let result = items.applyingWhatIf(percent: 100, toAssignmentIds: [1])
        XCTAssertEqual(result[0].whatIfPoints, 50)   // 100% of 50
        XCTAssertNil(result[1].whatIfPoints)         // untouched
    }

    func testBlanketOnlyAffectsUngraded() {
        let items = [item(1, group: 1, possible: 100, earned: 70),
                     item(2, group: 1, possible: 100, earned: nil)]
        let result = items.applyingBlanketToUngraded(percent: 80)
        XCTAssertNil(result[0].whatIfPoints)         // already graded → untouched
        XCTAssertEqual(result[1].whatIfPoints, 80)   // 80% of 100
    }

    func testPerfectRemainingSetsUngradedTo100() {
        let items = [item(1, group: 1, possible: 40, earned: nil)]
        let result = items.applyingPerfectRemaining()
        XCTAssertEqual(result[0].whatIfPoints, 40)
    }
}
