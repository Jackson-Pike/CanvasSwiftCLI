import Foundation

public struct GroupInfo {
    public let name: String
    public let weight: Double
    public var dropLowest: Int = 0
    public var dropHighest: Int = 0
    public var neverDrop: Set<Int> = []

    public init(name: String, weight: Double, dropLowest: Int = 0, dropHighest: Int = 0, neverDrop: Set<Int> = []) {
        self.name = name; self.weight = weight
        self.dropLowest = dropLowest; self.dropHighest = dropHighest; self.neverDrop = neverDrop
    }
}

public struct GroupResult {
    public let groupId: Int
    public let name: String
    public let weight: Double
    public let percent: Double?
}

public func buildGradedItems(groups: [AssignmentGroup], submissions: [Submission]) -> [GradedItem] {
    let scoreByAssignment = Dictionary(
        submissions.map { ($0.assignmentId, $0.score) },
        uniquingKeysWith: { first, _ in first }
    )
    return groups.flatMap { group in
        group.assignments.map { a in
            GradedItem(assignmentId: a.id, name: a.name, groupId: a.assignmentGroupId,
                       pointsPossible: a.pointsPossible,
                       earnedPoints: scoreByAssignment[a.id] ?? nil,
                       whatIfPoints: nil)
        }
    }
}

public struct GradeCalculator {
    public let items: [GradedItem]
    public let groups: [Int: GroupInfo]
    public let weighted: Bool

    public init(items: [GradedItem], groups: [Int: GroupInfo], weighted: Bool) {
        self.items = items; self.groups = groups; self.weighted = weighted
    }

    private func effectivePoints(_ item: GradedItem) -> Double? {
        item.whatIfPoints ?? item.earnedPoints
    }

    public func currentGrade() -> Double? {
        weighted ? weightedGrade() : unweightedGrade()
    }

    private func unweightedGrade() -> Double? {
        let graded = items.filter { effectivePoints($0) != nil }
        guard !graded.isEmpty else { return nil }
        let earned   = graded.reduce(0.0) { $0 + (effectivePoints($1) ?? 0) }
        let possible = graded.reduce(0.0) { $0 + $1.pointsPossible }
        guard possible > 0 else { return nil }
        return earned / possible * 100
    }

    func groupPercent(_ groupId: Int) -> Double? {
        let info = groups[groupId]
        var graded = items.filter { $0.groupId == groupId && effectivePoints($0) != nil }
        guard !graded.isEmpty else { return nil }
        if let info, (info.dropLowest > 0 || info.dropHighest > 0) {
            let neverDrop = info.neverDrop
            var droppable = graded.filter { !neverDrop.contains($0.assignmentId) }
            let pinned    = graded.filter {  neverDrop.contains($0.assignmentId) }
            droppable.sort {
                let pA = $0.pointsPossible > 0 ? (effectivePoints($0) ?? 0) / $0.pointsPossible : 0
                let pB = $1.pointsPossible > 0 ? (effectivePoints($1) ?? 0) / $1.pointsPossible : 0
                return pA < pB
            }
            let dropL = min(info.dropLowest, droppable.count)
            let dropH = min(info.dropHighest, max(0, droppable.count - dropL))
            graded = pinned + Array(droppable.dropFirst(dropL).dropLast(dropH))
        }
        guard !graded.isEmpty else { return nil }
        let earned   = graded.reduce(0.0) { $0 + (effectivePoints($1) ?? 0) }
        let possible = graded.reduce(0.0) { $0 + $1.pointsPossible }
        guard possible > 0 else { return nil }
        return earned / possible * 100
    }

    private func weightedGrade() -> Double? {
        var weightedSum = 0.0; var activeWeight = 0.0
        for (groupId, info) in groups {
            guard let pct = groupPercent(groupId) else { continue }
            weightedSum += (pct / 100) * info.weight
            activeWeight += info.weight
        }
        guard activeWeight > 0 else { return nil }
        return weightedSum / activeWeight * 100
    }

    public func groupBreakdown() -> [GroupResult] {
        groups.map { groupId, info in
            GroupResult(groupId: groupId, name: info.name, weight: info.weight, percent: groupPercent(groupId))
        }
    }
}

public extension Array where Element == GradedItem {
    func applyingWhatIf(percent: Double, toAssignmentIds ids: Set<Int>) -> [GradedItem] {
        map { item in
            guard ids.contains(item.assignmentId) else { return item }
            var copy = item; copy.whatIfPoints = item.pointsPossible * percent / 100; return copy
        }
    }
    func applyingBlanketToUngraded(percent: Double) -> [GradedItem] {
        map { item in
            guard item.earnedPoints == nil && item.whatIfPoints == nil else { return item }
            var copy = item; copy.whatIfPoints = item.pointsPossible * percent / 100; return copy
        }
    }
    func applyingPerfectRemaining() -> [GradedItem] { applyingBlanketToUngraded(percent: 100) }
}
