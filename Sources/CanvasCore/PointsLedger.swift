import Foundation

public struct PointsLedger: Equatable {
    public let earned: Double
    public let lost: Double
    public let inPlay: Double
    public let total: Double
    public init(earned: Double, lost: Double, inPlay: Double, total: Double) {
        self.earned = earned; self.lost = lost; self.inPlay = inPlay; self.total = total
    }
}

public extension GradeCalculator {
    func pointsLedger() -> PointsLedger {
        var earned = 0.0, lost = 0.0, inPlay = 0.0, total = 0.0
        for item in items {
            total += item.pointsPossible
            if let e = item.earnedPoints {
                earned += e
                lost += max(0, item.pointsPossible - e)
            } else {
                inPlay += item.pointsPossible
            }
        }
        return PointsLedger(earned: earned, lost: lost, inPlay: inPlay, total: total)
    }

    func ceilingGrade() -> Double? {
        GradeCalculator(items: items.applyingPerfectRemaining(),
                        groups: groups, weighted: weighted, gradingScale: gradingScale).currentGrade()
    }

    func floorGrade() -> Double? {
        GradeCalculator(items: items.applyingBlanketToUngraded(percent: 0),
                        groups: groups, weighted: weighted, gradingScale: gradingScale).currentGrade()
    }
}
