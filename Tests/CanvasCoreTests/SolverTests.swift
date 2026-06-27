import XCTest
@testable import CanvasCore

final class SolverTests: XCTestCase {
    private func item(_ id: Int, group: Int, possible: Double, earned: Double?) -> GradedItem {
        GradedItem(assignmentId: id, name: "A\(id)", groupId: group,
                   pointsPossible: possible, earnedPoints: earned, whatIfPoints: nil)
    }

    private func calcUnweighted(_ items: [GradedItem]) -> GradeCalculator {
        GradeCalculator(items: items, groups: [1: GroupInfo(name: "HW", weight: 100)], weighted: false)
    }

    func testAlreadyAchievedUnweighted() {
        // 90/100 = 90% — target 85%
        let items = [item(1, group: 1, possible: 100, earned: 90)]
        let result = calcUnweighted(items).solveForTarget(targetPercent: 85, solveAssignmentIds: [99])
        XCTAssertEqual(result, .alreadyAchieved)
    }

    func testNeededUnweighted() {
        // item 1: 60/100, item 2 ungraded 100pts — need 90% overall
        // require: (60 + x) / 200 >= 0.90 → x >= 120 → 120% impossible on 100pts
        // actually: need (60 + x)/200 = 0.90 → x = 120, impossible since max is 100
        // Let's use a case that's achievable: target 70%
        // (60 + x)/200 = 0.70 → x = 80 → 80%
        let items = [item(1, group: 1, possible: 100, earned: 60),
                     item(2, group: 1, possible: 100, earned: nil)]
        let result = calcUnweighted(items).solveForTarget(targetPercent: 70, solveAssignmentIds: [2])
        guard case .needed(let pct) = result else { XCTFail("Expected .needed, got \(result)"); return }
        XCTAssertEqual(pct, 80.0, accuracy: 0.2)
    }

    func testImpossibleUnweighted() {
        // item 1: 60/100, item 2 ungraded 100pts — target 90% needs 120pts on item2
        let items = [item(1, group: 1, possible: 100, earned: 60),
                     item(2, group: 1, possible: 100, earned: nil)]
        let result = calcUnweighted(items).solveForTarget(targetPercent: 90, solveAssignmentIds: [2])
        guard case .impossible(let max) = result else { XCTFail("Expected .impossible, got \(result)"); return }
        XCTAssertEqual(max, 80.0, accuracy: 0.2)  // (60+100)/200 = 80%
    }

    func testNeededWeighted() {
        // HW (40%): 90%. Final (60%): ungraded. Target: 80%
        // 0.9*40 + x*60 = 80*100 / 100 → 36 + 60x = 80 → 60x = 44 → x = 73.33%
        let items = [item(1, group: 1, possible: 100, earned: 90),
                     item(2, group: 2, possible: 100, earned: nil)]
        let groups: [Int: GroupInfo] = [
            1: GroupInfo(name: "HW", weight: 40),
            2: GroupInfo(name: "Final", weight: 60)
        ]
        let calc = GradeCalculator(items: items, groups: groups, weighted: true)
        let result = calc.solveForTarget(targetPercent: 80, solveAssignmentIds: [2])
        guard case .needed(let pct) = result else { XCTFail("Expected .needed, got \(result)"); return }
        XCTAssertEqual(pct, 73.33, accuracy: 0.5)
    }

    func testSolveAcrossMultipleAssignments() {
        // item1 graded 70/100, items 2 and 3 ungraded 50pts each — target 80%
        // need uniform X on items 2 and 3: (70 + 50x/100 + 50x/100)/200 = 0.80
        // (70 + x)/200 = 0.80 where x = points from both = 100x/100
        // 70 + 0.5x + 0.5x = 160 → 70 + x = 160 → x = 90% on each
        let items = [item(1, group: 1, possible: 100, earned: 70),
                     item(2, group: 1, possible: 50,  earned: nil),
                     item(3, group: 1, possible: 50,  earned: nil)]
        let result = calcUnweighted(items).solveForTarget(targetPercent: 80, solveAssignmentIds: [2, 3])
        guard case .needed(let pct) = result else { XCTFail("Expected .needed, got \(result)"); return }
        XCTAssertEqual(pct, 90.0, accuracy: 0.5)
    }
}
