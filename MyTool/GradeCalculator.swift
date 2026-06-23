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

    // weightedGrade() and groupBreakdown() implemented in Task 4.
    private func weightedGrade() -> Double? { nil }
    func groupBreakdown() -> [GroupResult] { [] }
}
