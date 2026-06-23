import Foundation

struct GroupInfo {
    let name: String
    let weight: Double      // 0–100
}

struct GroupResult {
    let groupId: Int
    let name: String
    let weight: Double
    let percent: Double?    // 0–100, nil when the group has no graded items
}

func buildGradedItems(groups: [AssignmentGroup], submissions: [Submission]) -> [GradedItem] {
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

struct GradeCalculator {
    let items: [GradedItem]
    let groups: [Int: GroupInfo]
    let weighted: Bool

    /// whatIf overrides real earned points when present.
    private func effectivePoints(_ item: GradedItem) -> Double? {
        item.whatIfPoints ?? item.earnedPoints
    }

    func currentGrade() -> Double? {
        if weighted { return weightedGrade() }
        return unweightedGrade()
    }

    private func unweightedGrade() -> Double? {
        let graded = items.filter { effectivePoints($0) != nil }
        guard !graded.isEmpty else { return nil }
        let earned = graded.reduce(0.0) { $0 + (effectivePoints($1) ?? 0) }
        let possible = graded.reduce(0.0) { $0 + $1.pointsPossible }
        guard possible > 0 else { return nil }
        return earned / possible * 100
    }

    /// Percent (0–100) for one group over its graded items only; nil if none graded.
    private func groupPercent(_ groupId: Int) -> Double? {
        let graded = items.filter { $0.groupId == groupId && effectivePoints($0) != nil }
        guard !graded.isEmpty else { return nil }
        let earned = graded.reduce(0.0) { $0 + (effectivePoints($1) ?? 0) }
        let possible = graded.reduce(0.0) { $0 + $1.pointsPossible }
        guard possible > 0 else { return nil }
        return earned / possible * 100
    }

    private func weightedGrade() -> Double? {
        var weightedSum = 0.0
        var activeWeight = 0.0
        for (groupId, info) in groups {
            guard let pct = groupPercent(groupId) else { continue }
            weightedSum += (pct / 100) * info.weight
            activeWeight += info.weight
        }
        guard activeWeight > 0 else { return nil }
        return weightedSum / activeWeight * 100
    }

    func groupBreakdown() -> [GroupResult] {
        groups.map { groupId, info in
            GroupResult(groupId: groupId, name: info.name, weight: info.weight, percent: groupPercent(groupId))
        }
    }
}

extension Array where Element == GradedItem {
    /// An item is "ungraded" when it has neither a real earned score nor a prior what-if.
    private func isUngraded(_ item: GradedItem) -> Bool {
        item.earnedPoints == nil && item.whatIfPoints == nil
    }

    func applyingWhatIf(percent: Double, toAssignmentIds ids: Set<Int>) -> [GradedItem] {
        map { item in
            guard ids.contains(item.assignmentId) else { return item }
            var copy = item
            copy.whatIfPoints = item.pointsPossible * percent / 100
            return copy
        }
    }

    func applyingBlanketToUngraded(percent: Double) -> [GradedItem] {
        map { item in
            guard isUngraded(item) else { return item }
            var copy = item
            copy.whatIfPoints = item.pointsPossible * percent / 100
            return copy
        }
    }

    func applyingPerfectRemaining() -> [GradedItem] {
        applyingBlanketToUngraded(percent: 100)
    }
}
