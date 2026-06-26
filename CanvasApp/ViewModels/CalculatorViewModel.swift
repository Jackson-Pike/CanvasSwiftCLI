import Foundation
import CanvasCore

@MainActor
final class CalculatorViewModel: ObservableObject {
    let course: Course
    let baseItems: [GradedItem]
    let groupInfo: [Int: GroupInfo]
    let gradingScale: [(String, Double)]

    @Published var whatIfEntries: [Int: WhatIfEntry] = [:]

    // Solve For Me
    @Published var targetMode: TargetMode = .letter
    @Published var targetLetter: String = "A"
    @Published var targetPercentInput: String = "90"
    @Published var solveScope: SolveScope = .single
    @Published var solveSingleId: Int?
    @Published var solveMultiIds: Set<Int> = []

    enum TargetMode { case letter, percent }
    enum SolveScope  { case single, spread }

    struct WhatIfEntry {
        var isActive: Bool = false
        var inputText: String = ""
        var inputMode: InputMode = .percent

        enum InputMode { case points, percent }

        func resolvedPercent(possiblePoints: Double) -> Double? {
            guard isActive, !inputText.isEmpty else { return nil }
            switch inputMode {
            case .percent:
                let cleaned = inputText.trimmingCharacters(in: .init(charactersIn: "%"))
                return Double(cleaned)
            case .points:
                guard let pts = Double(inputText), possiblePoints > 0 else { return nil }
                return pts / possiblePoints * 100
            }
        }

        func resolvedPoints(possiblePoints: Double) -> Double? {
            guard let pct = resolvedPercent(possiblePoints: possiblePoints) else { return nil }
            return possiblePoints * pct / 100
        }
    }

    init(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], gradingScale: [(String, Double)]) {
        self.course = course; self.baseItems = items
        self.groupInfo = groupInfo; self.gradingScale = gradingScale
        if let first = items.filter({ $0.earnedPoints == nil }).first {
            solveSingleId = first.assignmentId
        }
    }

    var effectiveItems: [GradedItem] {
        baseItems.map { item in
            guard let entry = whatIfEntries[item.assignmentId],
                  let pct = entry.resolvedPercent(possiblePoints: item.pointsPossible) else { return item }
            var copy = item
            copy.whatIfPoints = item.pointsPossible * pct / 100
            return copy
        }
    }

    var liveCalculator: GradeCalculator {
        GradeCalculator(items: effectiveItems, groups: groupInfo,
                        weighted: course.applyAssignmentGroupWeights ?? false, gradingScale: gradingScale)
    }

    var liveGrade: Double? { liveCalculator.currentGrade() }
    var liveBreakdown: [GroupResult] { liveCalculator.groupBreakdown().sorted { $0.weight > $1.weight } }

    var targetPercentValue: Double {
        switch targetMode {
        case .percent: return Double(targetPercentInput) ?? 90.0
        case .letter:  return gradingScale.first(where: { $0.0 == targetLetter })?.1 ?? 90.0
        }
    }

    var solveAssignmentIds: Set<Int> {
        switch solveScope {
        case .single:  return solveSingleId.map { [$0] } ?? []
        case .spread:  return solveMultiIds
        }
    }

    var solveResult: SolveResult? {
        guard !solveAssignmentIds.isEmpty else { return nil }
        return liveCalculator.solveForTarget(targetPercent: targetPercentValue,
                                              solveAssignmentIds: solveAssignmentIds)
    }

    var ungradedItems: [GradedItem] {
        baseItems.filter { $0.earnedPoints == nil }
    }

    func gradeLetter(for item: GradedItem) -> String? {
        guard let earned = item.earnedPoints, item.pointsPossible > 0 else { return nil }
        return letterGrade(for: earned / item.pointsPossible * 100, scale: gradingScale)
    }
}
